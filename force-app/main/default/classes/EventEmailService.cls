public with sharing class EventEmailService {
    
    public static void sendEventReminder(List<Event> upcomingEvents) {
        
        if (upcomingEvents.isEmpty() || upcomingEvents == null) {
            return;
        }

        List<Messaging.SingleEmailMessage> outbox = new List<Messaging.SingleEmailMessage>();

        for (Event eventRecord : upcomingEvents) {

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(eventRecord.OwnerId);
            mail.setSaveAsActivity(false);              
            mail.setSubject('You have an upcoming interview');
            mail.setHtmlBody(buildEventEmailBody(eventRecord));
            outbox.add(mail);
            } 
            if (!outBox.isEmpty()) {
                    Messaging.sendEmail(outBox);
            }    
        }      
        // HELPER METHODS

        // Build the email body
    private static String buildEventEmailBody(Event eventRecord) {    
        
        String emailBody = '<html><body>';

        emailBody += '<h2>Event Details</h2>';
        emailBody += '<p><strong>Event Name:</strong> ' + eventRecord.Subject + '</p>';
        emailBody += '<p><strong>Contact:</strong> ' + eventRecord.WhoId + '</p>';
    
        emailBody += '<p><strong>Date:</strong> ' + eventRecord.StartDateTime.format('MM/dd/yyyy') + '</p>';
        emailBody += '<p><strong>Time:</strong> ' + eventRecord.StartDateTime.format('h:mm a') + ' - ' + eventRecord.EndDateTime.format('h:mm a') + '</p>';
        if ( eventRecord.Location != null || eventRecord.Location != 'Remote') {
            emailBody += '<p><strong>Location:</strong> ' + event.Location + '</p>';
        } else { 
            if (eventRecord.get('MeetingLink__c') != null) {
                emailBody += '<p><strong>Meeting Link:</strong> ' + html(eventRecord.MeetingLink__c) + '</p>'; 
            }
        }
        if (eventRecord.Description != null) {
            emailBody += '<p><strong>Description:</strong> ' + html(eventRecord.Description) + '</p>'; 
        }
        emailBody += '<br><p>You got this!</p>';
        emailBody += '<p>Best Regards,<br>Your Event Team</p>';
        emailBody += '</body></html>';
        return emailBody;
    }
    
    private static String html(String s) {
    if (s == null) return '';
    return s
        .replace('&','&amp;')
        .replace('<','&lt;')
        .replace('>','&gt;')
        .replace('"','&quot;')
        .replace('\'','&#39;');
    }     
}
