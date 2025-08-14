package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"os"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/secretsmanager"
	influxdb2 "github.com/influxdata/influxdb-client-go/v2"
	"github.com/influxdata/influxdb-client-go/v2/api"
)

type WorkerResponse struct {
	StatusCode int             `json:"statusCode"`
	Timestamp  string          `json:"timestamp"`
	Environment string         `json:"environment"`
	Processing ProcessingSummary `json:"processing"`
}

type ProcessingSummary struct {
	TotalMessages      int                `json:"totalMessages"`
	SuccessfulMessages int                `json:"successfulMessages"`
	FailedMessages     int                `json:"failedMessages"`
	ProcessedItems     []ProcessedMessage `json:"processedItems"`
	FailedItems        []ProcessedMessage `json:"failedItems"`
}

type ProcessedMessage struct {
	WorkId    interface{} `json:"workId"`
	MessageId string      `json:"messageId"`
	Type      string      `json:"type"`
	Status    string      `json:"status"`
	Error     *string     `json:"error,omitempty"`
}

type WorkItem struct {
	ID      int                    `json:"id"`
	Type    string                 `json:"type"`
	Payload map[string]interface{} `json:"payload"`
}

type InfluxDBCredentials struct {
	Token string `json:"token"`
}

func Handler(ctx context.Context, sqsEvent events.SQSEvent) (WorkerResponse, error) {
	log.Printf("Worker Lambda triggered at: %s", time.Now().UTC().Format(time.RFC3339))
	log.Printf("Event: %+v", sqsEvent)

	var processedMessages []ProcessedMessage
	var failedMessages []ProcessedMessage
	var influxClient influxdb2.Client
	var writeAPI api.WriteAPI

	// Initialize AWS session with automatic region detection
	sess, err := session.NewSession()
	if err != nil {
		log.Printf("Failed to create AWS session: %v", err)
		return createWorkerErrorResponse(fmt.Sprintf("Failed to create AWS session: %v", err), len(sqsEvent.Records)), err
	}

	secretsMgr := secretsmanager.New(sess)

	defer func() {
		if writeAPI != nil {
			writeAPI.Flush()
			if influxClient != nil {
				influxClient.Close()
			}
			log.Println("InfluxDB connection closed")
		}
	}()

	// Get InfluxDB credentials from AWS Secrets Manager
	secretArn := os.Getenv("INFLUXDB_SECRET_ARN")
	secretInput := &secretsmanager.GetSecretValueInput{
		SecretId:     aws.String(secretArn),
		VersionStage: aws.String("AWSCURRENT"),
	}

	secretResult, err := secretsMgr.GetSecretValue(secretInput)
	if err != nil {
		errMsg := fmt.Sprintf("Failed to retrieve secret: %v", err)
		log.Println(errMsg)
		return createWorkerErrorResponse(errMsg, len(sqsEvent.Records)), err
	}

	var credentials InfluxDBCredentials
	if err := json.Unmarshal([]byte(*secretResult.SecretString), &credentials); err != nil {
		errMsg := fmt.Sprintf("Failed to parse credentials: %v", err)
		log.Println(errMsg)
		return createWorkerErrorResponse(errMsg, len(sqsEvent.Records)), err
	}

	influxURL := os.Getenv("INFLUXDB_URL")
	influxOrg := os.Getenv("INFLUXDB_ORG")
	influxBucket := os.Getenv("INFLUXDB_BUCKET")
	environment := os.Getenv("ENVIRONMENT")

	// Initialize InfluxDB client
	influxClient = influxdb2.NewClientWithOptions(
		influxURL,
		credentials.Token,
		influxdb2.DefaultOptions().SetUseGZip(true),
	)

	writeAPI = influxClient.WriteAPI(influxOrg, influxBucket)
	// WriteAPI options can be set if needed

	log.Println("Connected to InfluxDB")

	// Process each SQS record
	for _, record := range sqsEvent.Records {
		startTime := time.Now()
		var workItem WorkItem
		status := "success"
		var errorMessage *string

		log.Printf("Processing SQS record: %s", record.MessageId)

		// Parse the work item from SQS message
		if err := json.Unmarshal([]byte(record.Body), &workItem); err != nil {
			errMsg := fmt.Sprintf("Failed to parse work item: %v", err)
			log.Printf("Failed to parse work item from message %s: %v", record.MessageId, err)
			status = "error"
			errorMessage = &errMsg

			failedMessages = append(failedMessages, ProcessedMessage{
				WorkId:    "unknown",
				MessageId: record.MessageId,
				Type:      "unknown",
				Status:    status,
				Error:     errorMessage,
			})
		} else {
			log.Printf("Processing work item %d of type %s", workItem.ID, workItem.Type)

			// Process the work item based on its type
			if err := processWorkItem(workItem, writeAPI); err != nil {
				errMsg := err.Error()
				log.Printf("Failed to process work item %d: %v", workItem.ID, err)
				status = "error"
				errorMessage = &errMsg

				failedMessages = append(failedMessages, ProcessedMessage{
					WorkId:    workItem.ID,
					MessageId: record.MessageId,
					Type:      workItem.Type,
					Status:    status,
					Error:     errorMessage,
				})
			} else {
				processedMessages = append(processedMessages, ProcessedMessage{
					WorkId:    workItem.ID,
					MessageId: record.MessageId,
					Type:      workItem.Type,
					Status:    status,
				})

				log.Printf("Successfully processed work item %d", workItem.ID)
			}
		}

		// Log the processing attempt
		log.Printf("Work item processing completed for message %s: status=%s, duration=%dms",
			record.MessageId, status, time.Since(startTime).Milliseconds())

		// Write metrics to InfluxDB
		if writeAPI != nil {
			workType := "unknown"
			workId := 0
			if status != "error" || workItem.Type != "" {
				workType = workItem.Type
				workId = workItem.ID
			}

			point := influxdb2.NewPointWithMeasurement("work_item_processing").
				AddTag("work_type", workType).
				AddTag("status", status).
				AddTag("message_id", record.MessageId).
				AddField("work_id", workId).
				AddField("duration_ms", time.Since(startTime).Milliseconds()).
				SetTime(time.Now())

			if errorMessage != nil {
				point = point.AddField("error_message", *errorMessage)
			}

			writeAPI.WritePoint(point)
		}
	}

	// Determine status code based on processing results
	statusCode := 200
	if len(failedMessages) > 0 {
		statusCode = 207 // Multi-Status for partial failures
	}

	response := WorkerResponse{
		StatusCode:  statusCode,
		Timestamp:   time.Now().UTC().Format(time.RFC3339),
		Environment: environment,
		Processing: ProcessingSummary{
			TotalMessages:      len(sqsEvent.Records),
			SuccessfulMessages: len(processedMessages),
			FailedMessages:     len(failedMessages),
			ProcessedItems:     processedMessages,
			FailedItems:        failedMessages,
		},
	}

	log.Printf("Worker processing completed: %+v", response)
	return response, nil
}

func processWorkItem(workItem WorkItem, writeAPI api.WriteAPI) error {
	startTime := time.Now()

	switch workItem.Type {
	case "data_processing":
		if err := processDataItem(workItem.Payload, writeAPI); err != nil {
			return err
		}
	case "email_notification":
		if err := processEmailNotification(workItem.Payload, writeAPI); err != nil {
			return err
		}
	case "data_cleanup":
		if err := processDataCleanup(workItem.Payload, writeAPI); err != nil {
			return err
		}
	case "report_generation":
		if err := processReportGeneration(workItem.Payload, writeAPI); err != nil {
			return err
		}
	case "backup_task":
		if err := processBackupTask(workItem.Payload, writeAPI); err != nil {
			return err
		}
	default:
		return fmt.Errorf("unknown work item type: %s", workItem.Type)
	}

	// Log successful completion to InfluxDB
	if writeAPI != nil {
		point := influxdb2.NewPointWithMeasurement("work_item_completed").
			AddTag("work_type", workItem.Type).
			AddField("work_id", workItem.ID).
			AddField("processing_duration_ms", time.Since(startTime).Milliseconds()).
			SetTime(time.Now())

		writeAPI.WritePoint(point)
	}

	log.Printf("Completed processing for work item %d of type %s", workItem.ID, workItem.Type)
	return nil
}

func processDataItem(payload map[string]interface{}, writeAPI api.WriteAPI) error {
	log.Printf("Processing data item: %+v", payload)

	action, ok := payload["action"].(string)
	if !ok {
		return fmt.Errorf("missing or invalid action in payload")
	}

	if action == "update_profile" {
		// Simulate data processing work
		time.Sleep(100 * time.Millisecond)
		
		userIdFloat, ok := payload["userId"].(float64)
		if !ok {
			return fmt.Errorf("missing or invalid userId in payload")
		}
		userId := int(userIdFloat)
		
		log.Printf("Updated profile for user %d", userId)

		// Log user activity to InfluxDB
		if writeAPI != nil {
			point := influxdb2.NewPointWithMeasurement("user_activity").
				AddTag("action", action).
				AddField("user_id", userId).
				AddField("processing_time_ms", 100).
				SetTime(time.Now())

			writeAPI.WritePoint(point)
		}
	}

	return nil
}

func processEmailNotification(payload map[string]interface{}, writeAPI api.WriteAPI) error {
	log.Printf("Processing email notification: %+v", payload)

	email, ok := payload["email"].(string)
	if !ok {
		return fmt.Errorf("missing or invalid email in payload")
	}

	template, ok := payload["template"].(string)
	if !ok {
		return fmt.Errorf("missing or invalid template in payload")
	}

	// Simulate email sending work
	time.Sleep(200 * time.Millisecond)
	log.Printf("Email notification sent to %s using template %s", email, template)

	// Log email metrics to InfluxDB
	if writeAPI != nil {
		point := influxdb2.NewPointWithMeasurement("email_notifications").
			AddTag("template", template).
			AddTag("status", "sent").
			AddField("recipient", email).
			AddField("delivery_time_ms", 200).
			SetTime(time.Now())

		writeAPI.WritePoint(point)
	}

	return nil
}

func processDataCleanup(payload map[string]interface{}, writeAPI api.WriteAPI) error {
	log.Printf("Processing data cleanup: %+v", payload)

	table, ok := payload["table"].(string)
	if !ok {
		return fmt.Errorf("missing or invalid table in payload")
	}

	daysFloat, ok := payload["days"].(float64)
	if !ok {
		return fmt.Errorf("missing or invalid days in payload")
	}
	days := int(daysFloat)

	if table == "old_logs" {
		// Simulate cleanup operation
		time.Sleep(150 * time.Millisecond)
		recordsDeleted := rand.Intn(100) // Simulate random cleanup count
		log.Printf("Cleaned up %d records from %s older than %d days", recordsDeleted, table, days)

		// Log cleanup metrics to InfluxDB
		if writeAPI != nil {
			point := influxdb2.NewPointWithMeasurement("data_cleanup").
				AddTag("table", table).
				AddField("records_deleted", recordsDeleted).
				AddField("retention_days", days).
				AddField("cleanup_time_ms", 150).
				SetTime(time.Now())

			writeAPI.WritePoint(point)
		}
	}

	return nil
}

func processReportGeneration(payload map[string]interface{}, writeAPI api.WriteAPI) error {
	log.Printf("Processing report generation: %+v", payload)

	reportType, ok := payload["reportType"].(string)
	if !ok {
		return fmt.Errorf("missing or invalid reportType in payload")
	}

	userIdFloat, ok := payload["userId"].(float64)
	if !ok {
		return fmt.Errorf("missing or invalid userId in payload")
	}
	userId := int(userIdFloat)

	// Simulate report generation
	time.Sleep(300 * time.Millisecond)
	reportSize := rand.Intn(1000) + 100 // Simulate report size in KB
	log.Printf("Generated %s report for user %d (%dKB)", reportType, userId, reportSize)

	// Log report generation metrics to InfluxDB
	if writeAPI != nil {
		point := influxdb2.NewPointWithMeasurement("report_generation").
			AddTag("report_type", reportType).
			AddField("user_id", userId).
			AddField("report_size_kb", reportSize).
			AddField("generation_time_ms", 300).
			SetTime(time.Now())

		writeAPI.WritePoint(point)
	}

	return nil
}

func processBackupTask(payload map[string]interface{}, writeAPI api.WriteAPI) error {
	log.Printf("Processing backup task: %+v", payload)

	database, ok := payload["database"].(string)
	if !ok {
		return fmt.Errorf("missing or invalid database in payload")
	}

	retentionFloat, ok := payload["retention"].(float64)
	if !ok {
		return fmt.Errorf("missing or invalid retention in payload")
	}
	retention := int(retentionFloat)

	// Simulate backup operation
	time.Sleep(500 * time.Millisecond)
	backupSize := rand.Intn(10000) + 1000 // Simulate backup size in MB
	log.Printf("Backup completed for %s database with %d day retention (%dMB)", database, retention, backupSize)

	// Log backup metrics to InfluxDB
	if writeAPI != nil {
		point := influxdb2.NewPointWithMeasurement("database_backup").
			AddTag("database", database).
			AddField("backup_size_mb", backupSize).
			AddField("retention_days", retention).
			AddField("backup_time_ms", 500).
			SetTime(time.Now())

		writeAPI.WritePoint(point)
	}

	return nil
}

func createWorkerErrorResponse(errorMessage string, totalMessages int) WorkerResponse {
	environment := os.Getenv("ENVIRONMENT")
	if environment == "" {
		environment = "unknown"
	}

	return WorkerResponse{
		StatusCode:  500,
		Timestamp:   time.Now().UTC().Format(time.RFC3339),
		Environment: environment,
		Processing: ProcessingSummary{
			TotalMessages:      totalMessages,
			SuccessfulMessages: 0,
			FailedMessages:     totalMessages,
			ProcessedItems:     []ProcessedMessage{},
			FailedItems:        []ProcessedMessage{},
		},
	}
}

func main() {
	lambda.Start(Handler)
}