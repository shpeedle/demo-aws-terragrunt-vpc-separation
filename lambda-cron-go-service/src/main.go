package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strconv"
	"time"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/secretsmanager"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/aws/aws-sdk-go-v2/service/sqs/types"
	influxdb2 "github.com/influxdata/influxdb-client-go/v2"
	"github.com/influxdata/influxdb-client-go/v2/api"
)

type CronResponse struct {
	StatusCode  int         `json:"statusCode"`
	Timestamp   string      `json:"timestamp"`
	Environment string      `json:"environment"`
	CronJob     CronJobData `json:"cronJob"`
}

type CronJobData struct {
	Success       bool        `json:"success"`
	Error         *string     `json:"error"`
	ProcessedData interface{} `json:"processedData"`
}

type ProcessedData struct {
	MessagesSent    []MessageSent `json:"messagesSent"`
	ExecutionTimeMs int64         `json:"executionTimeMs"`
	Timestamp       string        `json:"timestamp"`
}

type MessageSent struct {
	WorkId    int    `json:"workId"`
	MessageId string `json:"messageId"`
	Type      string `json:"type"`
}

type WorkItem struct {
	ID      int                    `json:"id"`
	Type    string                 `json:"type"`
	Payload map[string]interface{} `json:"payload"`
}

type InfluxDBCredentials struct {
	Token string `json:"token"`
}


func Handler(ctx context.Context, event interface{}) (CronResponse, error) {
	log.Printf("Cron job triggered at: %s", time.Now().UTC().Format(time.RFC3339))
	log.Printf("Event: %+v", event)

	var processedData *ProcessedData
	var influxClient influxdb2.Client
	var writeAPI api.WriteAPI

	startTime := time.Now()

	// Initialize AWS config with automatic region detection
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return createErrorResponse(fmt.Sprintf("Failed to load AWS config: %v", err)), err
	}

	secretsMgr := secretsmanager.NewFromConfig(cfg)
	sqsClient := sqs.NewFromConfig(cfg)

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

	secretResult, err := secretsMgr.GetSecretValue(ctx, secretInput)
	if err != nil {
		errMsg := fmt.Sprintf("Failed to retrieve secret: %v", err)
		log.Println(errMsg)
		return createErrorResponse(errMsg), err
	}

	var credentials InfluxDBCredentials
	if err := json.Unmarshal([]byte(*secretResult.SecretString), &credentials); err != nil {
		errMsg := fmt.Sprintf("Failed to parse credentials: %v", err)
		log.Println(errMsg)
		return createErrorResponse(errMsg), err
	}

	influxURL := os.Getenv("INFLUXDB_URL")
	influxOrg := os.Getenv("INFLUXDB_ORG")
	influxBucket := os.Getenv("INFLUXDB_BUCKET")
	environment := os.Getenv("ENVIRONMENT")

	log.Printf("InfluxDB client initialized with URL: %s", influxURL)
	log.Printf("Using InfluxDB organization: %s", influxOrg)
	log.Printf("Using InfluxDB bucket: %s", influxBucket)

	// Initialize InfluxDB client
	influxClient = influxdb2.NewClientWithOptions(
		influxURL,
		credentials.Token,
		influxdb2.DefaultOptions().SetUseGZip(true),
	)

	writeAPI = influxClient.WriteAPI(influxOrg, influxBucket)
	// WriteAPI options can be set if needed

	log.Println("Connected to InfluxDB")

	// Log cron job start to InfluxDB
	cronStartPoint := influxdb2.NewPointWithMeasurement("cron_job_execution").
		AddTag("status", "started").
		AddTag("function_name", "lambda-cron-go").
		AddField("execution_start", 1).
		SetTime(time.Now())

	writeAPI.WritePoint(cronStartPoint)

	// Example work items to process
	workItems := []WorkItem{
		{ID: 1, Type: "data_processing", Payload: map[string]interface{}{"userId": 123, "action": "update_profile"}},
		{ID: 2, Type: "email_notification", Payload: map[string]interface{}{"email": "user@example.com", "template": "welcome"}},
		{ID: 3, Type: "data_cleanup", Payload: map[string]interface{}{"table": "old_logs", "days": 30}},
		{ID: 4, Type: "report_generation", Payload: map[string]interface{}{"reportType": "monthly", "userId": 456}},
		{ID: 5, Type: "backup_task", Payload: map[string]interface{}{"database": "main", "retention": 7}},
	}

	queueURL := os.Getenv("SQS_QUEUE_URL")
	if queueURL == "" {
		errMsg := "SQS_QUEUE_URL environment variable is not set"
		log.Println(errMsg)
		return createErrorResponse(errMsg), fmt.Errorf(errMsg)
	}

	// Process each work item by sending to SQS
	var messagesSent []MessageSent
	for _, item := range workItems {
		messageBody, err := json.Marshal(item)
		if err != nil {
			errMsg := fmt.Sprintf("Failed to marshal work item %d: %v", item.ID, err)
			log.Println(errMsg)
			return createErrorResponse(errMsg), err
		}

		messageParams := &sqs.SendMessageInput{
			QueueUrl:    aws.String(queueURL),
			MessageBody: aws.String(string(messageBody)),
			MessageAttributes: map[string]types.MessageAttributeValue{
				"workType": {
					DataType:    aws.String("String"),
					StringValue: aws.String(item.Type),
				},
				"workId": {
					DataType:    aws.String("Number"),
					StringValue: aws.String(strconv.Itoa(item.ID)),
				},
			},
		}

		result, err := sqsClient.SendMessage(ctx, messageParams)
		if err != nil {
			errMsg := fmt.Sprintf("Failed to send work item %d to SQS: %v", item.ID, err)
			log.Println(errMsg)
			return createErrorResponse(errMsg), err
		}

		messagesSent = append(messagesSent, MessageSent{
			WorkId:    item.ID,
			MessageId: *result.MessageId,
			Type:      item.Type,
		})

		log.Printf("Sent work item %d (%s) to SQS: %s", item.ID, item.Type, *result.MessageId)

		// Log SQS message metrics to InfluxDB
		sqsPoint := influxdb2.NewPointWithMeasurement("sqs_messages").
			AddTag("work_type", item.Type).
			AddTag("status", "sent").
			AddField("work_id", item.ID).
			AddField("message_id", *result.MessageId).
			SetTime(time.Now())

		writeAPI.WritePoint(sqsPoint)
	}

	executionDuration := time.Since(startTime)
	processedData = &ProcessedData{
		MessagesSent:    messagesSent,
		ExecutionTimeMs: executionDuration.Milliseconds(),
		Timestamp:       time.Now().UTC().Format(time.RFC3339),
	}

	// Log successful cron job completion to InfluxDB
	cronCompletePoint := influxdb2.NewPointWithMeasurement("cron_job_execution").
		AddTag("status", "completed").
		AddTag("function_name", "lambda-cron-go").
		AddField("messages_sent", len(messagesSent)).
		AddField("execution_duration_ms", executionDuration.Milliseconds()).
		SetTime(time.Now())

	writeAPI.WritePoint(cronCompletePoint)

	// Ensure all InfluxDB writes are flushed
	writeAPI.Flush()

	log.Printf("Cron job completed successfully: %+v", processedData)

	response := CronResponse{
		StatusCode:  200,
		Timestamp:   time.Now().UTC().Format(time.RFC3339),
		Environment: environment,
		CronJob: CronJobData{
			Success:       true,
			Error:         nil,
			ProcessedData: processedData,
		},
	}

	log.Printf("Cron job result: %+v", response)
	return response, nil
}

func createErrorResponse(errorMessage string) CronResponse {
	environment := os.Getenv("ENVIRONMENT")
	if environment == "" {
		environment = "unknown"
	}

	return CronResponse{
		StatusCode:  500,
		Timestamp:   time.Now().UTC().Format(time.RFC3339),
		Environment: environment,
		CronJob: CronJobData{
			Success:       false,
			Error:         &errorMessage,
			ProcessedData: nil,
		},
	}
}

func main() {
	lambda.Start(Handler)
}