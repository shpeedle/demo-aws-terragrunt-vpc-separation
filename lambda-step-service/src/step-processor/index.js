exports.handler = async (event) => {
    console.log('Processing data:', JSON.stringify(event, null, 2));
    
    try {
        // Simulate data processing
        const inputData = event.data || event;
        
        // Mock processing logic
        await new Promise(resolve => setTimeout(resolve, 1000));
        
        const processedData = {
            ...inputData,
            processedAt: new Date().toISOString(),
            processedBy: 'step-processor',
            status: 'processed',
            result: {
                recordCount: Math.floor(Math.random() * 1000) + 1,
                processedRecords: Math.floor(Math.random() * 950) + 1
            }
        };
        
        console.log('Processing completed:', JSON.stringify(processedData, null, 2));
        
        return processedData;
    } catch (error) {
        console.error('Processing failed:', error);
        throw new Error(`Processing failed: ${error.message}`);
    }
};