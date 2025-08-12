const AWS = require('aws-sdk');
const { Client } = require('pg');

exports.handler = async (event, context) => {
    console.log('Worker Lambda triggered at:', new Date().toISOString());
    console.log('Event:', JSON.stringify(event, null, 2));
    
    let client;
    const processedMessages = [];
    const failedMessages = [];
    
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
        
        // Create work item log table if it doesn't exist
        await client.query(`
            CREATE TABLE IF NOT EXISTS work_item_log (
                id SERIAL PRIMARY KEY,
                work_id INTEGER,
                work_type VARCHAR(50),
                message_id VARCHAR(255),
                status VARCHAR(20) DEFAULT 'processing',
                payload JSONB,
                processed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                processing_duration_ms INTEGER,
                error_message TEXT
            )
        `);
        
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
                await processWorkItem(workItem, client);
                
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
            
            // Log the processing attempt
            try {
                await client.query(
                    `INSERT INTO work_item_log (work_id, work_type, message_id, status, payload, processing_duration_ms, error_message) 
                     VALUES ($1, $2, $3, $4, $5, $6, $7)`,
                    [
                        workItem?.id || null,
                        workItem?.type || 'unknown',
                        record.messageId,
                        status,
                        JSON.stringify(workItem || {}),
                        Date.now() - startTime,
                        errorMessage
                    ]
                );
            } catch (logError) {
                console.error('Failed to log work item processing:', logError);
            }
        }
        
    } catch (err) {
        console.error('Worker Lambda error:', err);
        throw err; // Re-throw to trigger SQS retry/DLQ behavior
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
async function processWorkItem(workItem, client) {
    const { id, type, payload } = workItem;
    
    switch (type) {
        case 'data_processing':
            await processDataItem(payload, client);
            break;
            
        case 'email_notification':
            await processEmailNotification(payload, client);
            break;
            
        case 'data_cleanup':
            await processDataCleanup(payload, client);
            break;
            
        case 'report_generation':
            await processReportGeneration(payload, client);
            break;
            
        case 'backup_task':
            await processBackupTask(payload, client);
            break;
            
        default:
            throw new Error(`Unknown work item type: ${type}`);
    }
    
    console.log(`Completed processing for work item ${id} of type ${type}`);
}

// Individual work item processors
async function processDataItem(payload, client) {
    console.log('Processing data item:', payload);
    
    // Example: Update user profile
    if (payload.action === 'update_profile') {
        // Simulate data processing work
        await new Promise(resolve => setTimeout(resolve, 100));
        console.log(`Updated profile for user ${payload.userId}`);
    }
}

async function processEmailNotification(payload, client) {
    console.log('Processing email notification:', payload);
    
    // Example: Send email notification
    // In a real scenario, this would integrate with SES, SendGrid, etc.
    await new Promise(resolve => setTimeout(resolve, 200));
    console.log(`Email notification sent to ${payload.email} using template ${payload.template}`);
}

async function processDataCleanup(payload, client) {
    console.log('Processing data cleanup:', payload);
    
    // Example: Clean up old data
    if (payload.table === 'old_logs') {
        // Simulate cleanup operation
        await new Promise(resolve => setTimeout(resolve, 150));
        console.log(`Cleaned up ${payload.table} older than ${payload.days} days`);
    }
}

async function processReportGeneration(payload, client) {
    console.log('Processing report generation:', payload);
    
    // Example: Generate report
    await new Promise(resolve => setTimeout(resolve, 300));
    console.log(`Generated ${payload.reportType} report for user ${payload.userId}`);
}

async function processBackupTask(payload, client) {
    console.log('Processing backup task:', payload);
    
    // Example: Perform backup
    await new Promise(resolve => setTimeout(resolve, 500));
    console.log(`Backup completed for ${payload.database} database with ${payload.retention} day retention`);
}