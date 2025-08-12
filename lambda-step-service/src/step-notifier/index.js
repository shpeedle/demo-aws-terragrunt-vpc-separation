exports.handler = async (event) => {
    console.log('Sending notification:', JSON.stringify(event, null, 2));
    
    try {
        const { status, message, data, error } = event;
        
        // Mock notification logic
        await new Promise(resolve => setTimeout(resolve, 300));
        
        const notification = {
            notificationId: `notif-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
            timestamp: new Date().toISOString(),
            status: status || 'info',
            message: message || 'Notification sent',
            sentBy: 'step-notifier'
        };
        
        if (status === 'success') {
            console.log('SUCCESS NOTIFICATION:', {
                ...notification,
                summary: {
                    recordsProcessed: data?.result?.processedRecords || 0,
                    totalRecords: data?.result?.recordCount || 0,
                    validationPassed: data?.isValid || false
                }
            });
        } else if (status === 'error') {
            console.log('ERROR NOTIFICATION:', {
                ...notification,
                error: error || 'Unknown error occurred',
                failureDetails: data?.validationResult?.checks?.filter(check => !check.passed) || []
            });
        } else {
            console.log('INFO NOTIFICATION:', notification);
        }
        
        // In a real implementation, this would send to SNS, SES, Slack, etc.
        console.log('Notification sent successfully');
        
        return {
            ...notification,
            delivered: true
        };
    } catch (error) {
        console.error('Notification failed:', error);
        throw new Error(`Notification failed: ${error.message}`);
    }
};