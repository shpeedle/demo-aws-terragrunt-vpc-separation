const AWS = require('aws-sdk');
const { InfluxDB, Point } = require('@influxdata/influxdb-client');

const secretsManager = new AWS.SecretsManager();

exports.handler = async (event, context) => {
    console.log('Worker Lambda triggered at:', new Date().toISOString());
    console.log('Event:', JSON.stringify(event, null, 2));
    
    const processedMessages = [];
    const failedMessages = [];
    let influxClient;
    let writeApi;
    
    try {
        // Get InfluxDB credentials from AWS Secrets Manager
        const secretResponse = await secretsManager.getSecretValue({
            SecretId: process.env.INFLUXDB_SECRET_ARN,
            VersionStage: "AWSCURRENT" // Explicitly request current version
        }).promise();
        
        const credentials = JSON.parse(secretResponse.SecretString);
        
        // Initialize InfluxDB client
        influxClient = new InfluxDB({
            url: process.env.INFLUXDB_URL,
            token: credentials.token // Use the correct token field
        });
        
        writeApi = influxClient.getWriteApi(process.env.INFLUXDB_ORG, process.env.INFLUXDB_BUCKET);
        writeApi.useDefaultTags({ host: 'lambda-worker', environment: process.env.ENVIRONMENT });
        
        console.log('Connected to InfluxDB');
        
        // Process each SQS record
        for (const record of event.Records) {
            const startTime = Date.now();
            let workItem;
            let status = 'success';
            let errorMessage = null;
            
            try {
                // Parse the work item from SQS message
                workItem = JSON.parse(record.body);
                console.log(`Processing work item ${workItem.id} of type ${workItem.type}`);
                
                // Process the work item based on its type
                await processWorkItem(workItem, writeApi);
                
                processedMessages.push({
                    workId: workItem.id,
                    messageId: record.messageId,
                    type: workItem.type,
                    status: 'success'
                });
                
                console.log(`Successfully processed work item ${workItem.id}`);
                
            } catch (processingError) {
                console.error(`Failed to process work item:`, processingError);
                status = 'error';
                errorMessage = processingError.message;
                
                failedMessages.push({
                    workId: workItem?.id || 'unknown',
                    messageId: record.messageId,
                    type: workItem?.type || 'unknown',
                    status: 'error',
                    error: errorMessage
                });
            }
            
            // Log the processing attempt to console and InfluxDB
            console.log(`Work item ${workItem?.id || 'unknown'} (${workItem?.type || 'unknown'}) processing completed:`, {
                messageId: record.messageId,
                status: status,
                duration: Date.now() - startTime,
                error: errorMessage
            });
            
            // Write metrics to InfluxDB
            if (writeApi) {
                try {
                    const point = new Point('work_item_processing')
                        .tag('work_type', workItem?.type || 'unknown')
                        .tag('status', status)
                        .tag('message_id', record.messageId)
                        .intField('work_id', workItem?.id || 0)
                        .intField('duration_ms', Date.now() - startTime);
                    
                    if (errorMessage) {
                        point.stringField('error_message', errorMessage);
                    }
                    
                    writeApi.writePoint(point);
                } catch (influxError) {
                    console.error('Failed to write metrics to InfluxDB:', influxError);
                }
            }
        }
        
    } catch (err) {
        console.error('Worker Lambda error:', err);
        throw err; // Re-throw to trigger SQS retry/DLQ behavior
    } finally {
        // Close InfluxDB connection
        if (writeApi) {
            try {
                await writeApi.close();
                console.log('InfluxDB connection closed');
            } catch (err) {
                console.error('Error closing InfluxDB connection:', err);
            }
        }
    }
    
    // Return processing summary
    const result = {
        statusCode: failedMessages.length > 0 ? 207 : 200, // 207 Multi-Status for partial failures
        timestamp: new Date().toISOString(),
        environment: process.env.ENVIRONMENT || 'unknown',
        processing: {
            totalMessages: event.Records.length,
            successfulMessages: processedMessages.length,
            failedMessages: failedMessages.length,
            processedItems: processedMessages,
            failedItems: failedMessages
        }
    };
    
    console.log('Worker processing completed:', JSON.stringify(result, null, 2));
    return result;
};

// Function to process different types of work items
async function processWorkItem(workItem, writeApi) {
    const { id, type, payload } = workItem;
    const startTime = Date.now();
    
    switch (type) {
        case 'data_processing':
            await processDataItem(payload, writeApi);
            break;
            
        case 'email_notification':
            await processEmailNotification(payload, writeApi);
            break;
            
        case 'data_cleanup':
            await processDataCleanup(payload, writeApi);
            break;
            
        case 'report_generation':
            await processReportGeneration(payload, writeApi);
            break;
            
        case 'backup_task':
            await processBackupTask(payload, writeApi);
            break;
            
        default:
            throw new Error(`Unknown work item type: ${type}`);
    }
    
    // Log successful completion to InfluxDB
    if (writeApi) {
        try {
            const point = new Point('work_item_completed')
                .tag('work_type', type)
                .intField('work_id', id)
                .intField('processing_duration_ms', Date.now() - startTime);
            
            writeApi.writePoint(point);
        } catch (influxError) {
            console.error('Failed to write completion metrics to InfluxDB:', influxError);
        }
    }
    
    console.log(`Completed processing for work item ${id} of type ${type}`);
}

// Individual work item processors
async function processDataItem(payload, writeApi) {
    console.log('Processing data item:', payload);
    
    // Example: Update user profile
    if (payload.action === 'update_profile') {
        // Simulate data processing work
        await new Promise(resolve => setTimeout(resolve, 100));
        console.log(`Updated profile for user ${payload.userId}`);
        
        // Log user activity to InfluxDB
        if (writeApi) {
            try {
                const point = new Point('user_activity')
                    .tag('action', payload.action)
                    .intField('user_id', payload.userId)
                    .intField('processing_time_ms', 100);
                
                writeApi.writePoint(point);
            } catch (influxError) {
                console.error('Failed to log user activity to InfluxDB:', influxError);
            }
        }
    }
}

async function processEmailNotification(payload, writeApi) {
    console.log('Processing email notification:', payload);
    
    // Example: Send email notification
    // In a real scenario, this would integrate with SES, SendGrid, etc.
    await new Promise(resolve => setTimeout(resolve, 200));
    console.log(`Email notification sent to ${payload.email} using template ${payload.template}`);
    
    // Log email metrics to InfluxDB
    if (writeApi) {
        try {
            const point = new Point('email_notifications')
                .tag('template', payload.template)
                .tag('status', 'sent')
                .stringField('recipient', payload.email)
                .intField('delivery_time_ms', 200);
            
            writeApi.writePoint(point);
        } catch (influxError) {
            console.error('Failed to log email metrics to InfluxDB:', influxError);
        }
    }
}

async function processDataCleanup(payload, writeApi) {
    console.log('Processing data cleanup:', payload);
    
    // Example: Clean up old data
    if (payload.table === 'old_logs') {
        // Simulate cleanup operation
        await new Promise(resolve => setTimeout(resolve, 150));
        const recordsDeleted = Math.floor(Math.random() * 100); // Simulate random cleanup count
        console.log(`Cleaned up ${recordsDeleted} records from ${payload.table} older than ${payload.days} days`);
        
        // Log cleanup metrics to InfluxDB
        if (writeApi) {
            try {
                const point = new Point('data_cleanup')
                    .tag('table', payload.table)
                    .intField('records_deleted', recordsDeleted)
                    .intField('retention_days', payload.days)
                    .intField('cleanup_time_ms', 150);
                
                writeApi.writePoint(point);
            } catch (influxError) {
                console.error('Failed to log cleanup metrics to InfluxDB:', influxError);
            }
        }
    }
}

async function processReportGeneration(payload, writeApi) {
    console.log('Processing report generation:', payload);
    
    // Example: Generate report
    await new Promise(resolve => setTimeout(resolve, 300));
    const reportSize = Math.floor(Math.random() * 1000) + 100; // Simulate report size in KB
    console.log(`Generated ${payload.reportType} report for user ${payload.userId} (${reportSize}KB)`);
    
    // Log report generation metrics to InfluxDB
    if (writeApi) {
        try {
            const point = new Point('report_generation')
                .tag('report_type', payload.reportType)
                .intField('user_id', payload.userId)
                .intField('report_size_kb', reportSize)
                .intField('generation_time_ms', 300);
            
            writeApi.writePoint(point);
        } catch (influxError) {
            console.error('Failed to log report metrics to InfluxDB:', influxError);
        }
    }
}

async function processBackupTask(payload, writeApi) {
    console.log('Processing backup task:', payload);
    
    // Example: Perform backup
    await new Promise(resolve => setTimeout(resolve, 500));
    const backupSize = Math.floor(Math.random() * 10000) + 1000; // Simulate backup size in MB
    console.log(`Backup completed for ${payload.database} database with ${payload.retention} day retention (${backupSize}MB)`);
    
    // Log backup metrics to InfluxDB
    if (writeApi) {
        try {
            const point = new Point('database_backup')
                .tag('database', payload.database)
                .intField('backup_size_mb', backupSize)
                .intField('retention_days', payload.retention)
                .intField('backup_time_ms', 500);
            
            writeApi.writePoint(point);
        } catch (influxError) {
            console.error('Failed to log backup metrics to InfluxDB:', influxError);
        }
    }
}