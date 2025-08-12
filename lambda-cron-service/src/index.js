const AWS = require('aws-sdk');
const { Client } = require('pg');

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
        
        // Simulate some cron job work (e.g., data cleanup, reporting, etc.)
        const startTime = Date.now();
        
        // Example: Clean up old health check records (older than 24 hours)
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
                `Hourly cleanup job completed. Deleted ${deletedRecords} old health check records.`,
                deletedRecords,
                executionDuration
            ]
        );
        
        // Get recent cron job executions for monitoring
        const logResult = await client.query(
            'SELECT id, execution_time, status, message, processed_records, execution_duration_ms FROM cron_job_log ORDER BY execution_time DESC LIMIT 10'
        );
        
        dbResult = logResult.rows;
        processedData = {
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