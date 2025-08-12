exports.handler = async (event) => {
    console.log('Validating data:', JSON.stringify(event, null, 2));
    
    try {
        const data = event.data || event;
        
        // Mock validation logic
        await new Promise(resolve => setTimeout(resolve, 500));
        
        const isValid = data.result && 
                       data.result.recordCount > 0 && 
                       data.result.processedRecords > 0 &&
                       data.result.processedRecords <= data.result.recordCount;
        
        const validatedData = {
            ...data,
            validatedAt: new Date().toISOString(),
            validatedBy: 'step-validator',
            isValid: isValid,
            validationResult: {
                checks: [
                    {
                        name: 'record_count_check',
                        passed: data.result && data.result.recordCount > 0,
                        message: data.result && data.result.recordCount > 0 ? 'Record count is valid' : 'Invalid record count'
                    },
                    {
                        name: 'processed_records_check',
                        passed: data.result && data.result.processedRecords > 0,
                        message: data.result && data.result.processedRecords > 0 ? 'Processed records count is valid' : 'Invalid processed records count'
                    },
                    {
                        name: 'consistency_check',
                        passed: data.result && data.result.processedRecords <= data.result.recordCount,
                        message: data.result && data.result.processedRecords <= data.result.recordCount ? 'Data consistency check passed' : 'Data consistency check failed'
                    }
                ]
            }
        };
        
        console.log('Validation completed:', JSON.stringify(validatedData, null, 2));
        
        return validatedData;
    } catch (error) {
        console.error('Validation failed:', error);
        throw new Error(`Validation failed: ${error.message}`);
    }
};