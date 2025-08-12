const AWS = require('aws-sdk');
const { Client } = require('pg');

const sqs = new AWS.SQS();

exports.handler = async (event, context) => {
    console.log('Cron job triggered at:', new Date().toISOString());
    console.log('Event:', JSON.stringify(event, null, 2));
    console.log('Context:', JSON.stringify(context, null, 2));
    
    let client;
    let dbResult = null;
    let error = null;
    let processedData = null;
    
    try {
        // Database connection configuration
        client = new Client({
            host: process.env.DB_HOST,
            port: process.env.DB_PORT || 5432,
            database: process.env.DB_NAME,
            user: process.env.DB_USERNAME,
            password: process.env.DB_PASSWORD,
            ssl: {
                rejectUnauthorized: false
            }
        });
        
        await client.connect();
        console.log('Connected to PostgreSQL database');
        
        // Create cron job execution log table if it doesn't exist
        await client.query(`
            CREATE TABLE IF NOT EXISTS cron_job_log (
                id SERIAL PRIMARY KEY,
                execution_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                status VARCHAR(20) DEFAULT 'success',
                message TEXT,
                processed_records INTEGER DEFAULT 0,
                execution_duration_ms INTEGER
            )
        `);
        
        // Simulate some cron job work and process work items
        const startTime = Date.now();
        
        // Example work items to process (in real scenario, this could come from database, API, etc.)
        const workItems = [
            { id: 1, type: 'data_processing', payload: { userId: 123, action: 'update_profile' } },
            { id: 2, type: 'email_notification', payload: { email: 'user@example.com', template: 'welcome' } },
            { id: 3, type: 'data_cleanup', payload: { table: 'old_logs', days: 30 } },
            { id: 4, type: 'report_generation', payload: { reportType: 'monthly', userId: 456 } },
            { id: 5, type: 'backup_task', payload: { database: 'main', retention: 7 } }
        ];
        
        // SQS Queue URL from environment variable
        const queueUrl = process.env.SQS_QUEUE_URL;
        
        if (!queueUrl) {
            throw new Error('SQS_QUEUE_URL environment variable is not set');
        }
        
        // Process each work item by sending to SQS
        const messagesSent = [];
        for (const item of workItems) {
            try {
                const messageParams = {
                    QueueUrl: queueUrl,
                    MessageBody: JSON.stringify(item),
                    MessageAttributes: {
                        'workType': {
                            DataType: 'String',
                            StringValue: item.type
                        },
                        'workId': {
                            DataType: 'Number',
                            StringValue: item.id.toString()
                        }
                    }
                };
                
                const result = await sqs.sendMessage(messageParams).promise();
                messagesSent.push({
                    workId: item.id,
                    messageId: result.MessageId,
                    type: item.type
                });
                
                console.log(`Sent work item ${item.id} (${item.type}) to SQS: ${result.MessageId}`);
            } catch (sqsError) {
                console.error(`Failed to send work item ${item.id} to SQS:`, sqsError);
                throw sqsError;
            }
        }
        
        // Example: Clean up old health check records (older than 24 hours) - existing cleanup logic
        await client.query(`
            CREATE TABLE IF NOT EXISTS health_check (
                id SERIAL PRIMARY KEY,
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                message TEXT
            )
        `);
        
        const cleanupResult = await client.query(`
            DELETE FROM health_check 
            WHERE timestamp < NOW() - INTERVAL '24 hours'
        `);
        
        const deletedRecords = cleanupResult.rowCount || 0;
        const executionDuration = Date.now() - startTime;
        
        // Log the cron job execution
        await client.query(
            `INSERT INTO cron_job_log (status, message, processed_records, execution_duration_ms) 
             VALUES ($1, $2, $3, $4)`,
            [
                'success',
                `Hourly cron job completed. Sent ${messagesSent.length} work items to SQS. Deleted ${deletedRecords} old health check records.`,
                messagesSent.length + deletedRecords,
                executionDuration
            ]
        );
        
        // Get recent cron job executions for monitoring
        const logResult = await client.query(
            'SELECT id, execution_time, status, message, processed_records, execution_duration_ms FROM cron_job_log ORDER BY execution_time DESC LIMIT 10'
        );
        
        dbResult = logResult.rows;
        processedData = {
            messagesSent: messagesSent,
            recordsDeleted: deletedRecords,
            executionTimeMs: executionDuration,
            timestamp: new Date().toISOString()
        };
        
        console.log('Cron job completed successfully:', processedData);
        
    } catch (err) {
        console.error('Cron job error:', err);
        error = err.message;
        
        // Try to log the error if database connection is available
        if (client) {
            try {
                await client.query(
                    `INSERT INTO cron_job_log (status, message, processed_records, execution_duration_ms) 
                     VALUES ($1, $2, $3, $4)`,
                    ['error', error, 0, Date.now() - (processedData?.timestamp ? new Date(processedData.timestamp).getTime() : Date.now())]
                );
            } catch (logError) {
                console.error('Failed to log error to database:', logError);
            }
        }
    } finally {
        if (client) {
            try {
                await client.end();
                console.log('Database connection closed');
            } catch (err) {
                console.error('Error closing database connection:', err);
            }
        }
    }
    
    // Return result for monitoring and logging
    const result = {
        statusCode: error ? 500 : 200,
        timestamp: new Date().toISOString(),
        environment: process.env.ENVIRONMENT || 'unknown',
        cronJob: {
            success: !error,
            error: error,
            processedData: processedData,
            recentExecutions: dbResult
        }
    };
    
    console.log('Cron job result:', JSON.stringify(result, null, 2));
    return result;
};