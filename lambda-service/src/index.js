const AWS = require('aws-sdk');
const { Client } = require('pg');

exports.handler = async (event) => {
    console.log('Event:', JSON.stringify(event, null, 2));
    
    let client;
    let dbResult = null;
    let error = null;
    
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
        
        // Create a simple test table if it doesn't exist
        await client.query(`
            CREATE TABLE IF NOT EXISTS health_check (
                id SERIAL PRIMARY KEY,
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                message TEXT
            )
        `);
        
        // Insert a test record
        await client.query(
            'INSERT INTO health_check (message) VALUES ($1)',
            [`Lambda execution at ${new Date().toISOString()}`]
        );
        
        // Query the table
        const result = await client.query(
            'SELECT id, timestamp, message FROM health_check ORDER BY timestamp DESC LIMIT 5'
        );
        
        dbResult = result.rows;
        console.log('Database query successful:', dbResult);
        
    } catch (err) {
        console.error('Database error:', err);
        error = err.message;
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
    
    const response = {
        statusCode: error ? 500 : 200,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        body: JSON.stringify({
            message: error ? 'Database connection failed' : 'Hello from Lambda with Database!',
            timestamp: new Date().toISOString(),
            environment: process.env.ENVIRONMENT || 'unknown',
            database: {
                connected: !error,
                error: error,
                query_results: dbResult
            }
        })
    };
    
    return response;
};