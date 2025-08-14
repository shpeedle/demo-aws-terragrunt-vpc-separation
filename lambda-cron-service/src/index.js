const AWS = require("aws-sdk");
const { InfluxDB, Point } = require("@influxdata/influxdb-client");

const sqs = new AWS.SQS();
const secretsManager = new AWS.SecretsManager();

exports.handler = async (event, context) => {
  console.log("Cron job triggered at:", new Date().toISOString());
  console.log("Event:", JSON.stringify(event, null, 2));
  console.log("Context:", JSON.stringify(context, null, 2));

  let error = null;
  let processedData = null;
  let influxClient;
  let writeApi;

  try {
    // Get InfluxDB credentials from AWS Secrets Manager
    const secretResponse = await secretsManager
      .getSecretValue({
        SecretId: process.env.INFLUXDB_SECRET_ARN,
        VersionStage: "AWSCURRENT", // Explicitly request current version
      })
      .promise();

    const credentials = JSON.parse(secretResponse.SecretString);

    console.log(
      "InfluxDB client initialized with URL:",
      process.env.INFLUXDB_URL
    );
    console.log("Using InfluxDB organization:", process.env.INFLUXDB_ORG);
    console.log("Using InfluxDB bucket:", process.env.INFLUXDB_BUCKET);

    // Initialize InfluxDB client for Timestream InfluxDB using token authentication
    influxClient = new InfluxDB({
      url: process.env.INFLUXDB_URL,
      token: credentials.token,
      timeout: 10000,
    });

    writeApi = influxClient.getWriteApi(
      process.env.INFLUXDB_ORG,
      process.env.INFLUXDB_BUCKET
    );
    writeApi.useDefaultTags({
      host: "lambda-cron",
      environment: process.env.ENVIRONMENT,
    });

    console.log("Connected to InfluxDB");

    // Simulate some cron job work and process work items
    const startTime = Date.now();

    // Log cron job start to InfluxDB
    const cronStartPoint = new Point("cron_job_execution")
      .tag("status", "started")
      .tag("function_name", context.functionName)
      .stringField("request_id", context.awsRequestId);

    writeApi.writePoint(cronStartPoint);

    // Example work items to process (in real scenario, this could come from database, API, etc.)
    const workItems = [
      {
        id: 1,
        type: "data_processing",
        payload: { userId: 123, action: "update_profile" },
      },
      {
        id: 2,
        type: "email_notification",
        payload: { email: "user@example.com", template: "welcome" },
      },
      { id: 3, type: "data_cleanup", payload: { table: "old_logs", days: 30 } },
      {
        id: 4,
        type: "report_generation",
        payload: { reportType: "monthly", userId: 456 },
      },
      {
        id: 5,
        type: "backup_task",
        payload: { database: "main", retention: 7 },
      },
    ];

    // SQS Queue URL from environment variable
    const queueUrl = process.env.SQS_QUEUE_URL;

    if (!queueUrl) {
      throw new Error("SQS_QUEUE_URL environment variable is not set");
    }

    // Process each work item by sending to SQS
    const messagesSent = [];
    for (const item of workItems) {
      try {
        const messageParams = {
          QueueUrl: queueUrl,
          MessageBody: JSON.stringify(item),
          MessageAttributes: {
            workType: {
              DataType: "String",
              StringValue: item.type,
            },
            workId: {
              DataType: "Number",
              StringValue: item.id.toString(),
            },
          },
        };

        const result = await sqs.sendMessage(messageParams).promise();
        messagesSent.push({
          workId: item.id,
          messageId: result.MessageId,
          type: item.type,
        });

        console.log(
          `Sent work item ${item.id} (${item.type}) to SQS: ${result.MessageId}`
        );

        // Log SQS message metrics to InfluxDB
        const sqsPoint = new Point("sqs_messages")
          .tag("work_type", item.type)
          .tag("status", "sent")
          .intField("work_id", item.id)
          .stringField("message_id", result.MessageId);

        writeApi.writePoint(sqsPoint);
      } catch (sqsError) {
        console.error(`Failed to send work item ${item.id} to SQS:`, sqsError);
        throw sqsError;
      }
    }

    const executionDuration = Date.now() - startTime;
    processedData = {
      messagesSent: messagesSent,
      executionTimeMs: executionDuration,
      timestamp: new Date().toISOString(),
    };

    // Log successful cron job completion to InfluxDB
    const cronCompletePoint = new Point("cron_job_execution")
      .tag("status", "completed")
      .tag("function_name", context.functionName)
      .intField("messages_sent", messagesSent.length)
      .intField("execution_duration_ms", executionDuration)
      .stringField("request_id", context.awsRequestId);

    writeApi.writePoint(cronCompletePoint);

    // Ensure all InfluxDB writes are flushed
    await writeApi.flush();

    console.log("Cron job completed successfully:", processedData);
  } catch (err) {
    console.error("Cron job error:", err);
    error = err.message;

    // Log error to InfluxDB
    if (writeApi) {
      try {
        const errorPoint = new Point("cron_job_execution")
          .tag("status", "error")
          .tag("function_name", context.functionName)
          .stringField("error_message", error)
          .stringField("request_id", context.awsRequestId);

        writeApi.writePoint(errorPoint);
        await writeApi.flush();
      } catch (influxError) {
        console.error("Failed to log error to InfluxDB:", influxError);
      }
    }

    // Re-throw the error to make the Lambda function fail
    throw err;
  } finally {
    // Close InfluxDB connection
    if (writeApi) {
      try {
        await writeApi.close();
        console.log("InfluxDB connection closed");
      } catch (err) {
        console.error("Error closing InfluxDB connection:", err);
      }
    }
  }

  // Return result for monitoring and logging (only on success)
  const result = {
    statusCode: 200,
    timestamp: new Date().toISOString(),
    environment: process.env.ENVIRONMENT || "unknown",
    cronJob: {
      success: true,
      error: null,
      processedData: processedData,
    },
  };

  console.log("Cron job result:", JSON.stringify(result, null, 2));
  return result;
};
