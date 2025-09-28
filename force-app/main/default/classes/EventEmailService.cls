public with sharing class EventEmailService {
    
    public static void sendEventReminder(List<Event> upcomingEvents) {
        if (upcomingEvents == null || upcomingEvents.isEmpty()) return;

        // Look up the Org-Wide Email Address by email (safe query)
    List<OrgWideEmailAddress> owes = [
        SELECT Id FROM OrgWideEmailAddress
        WHERE Address = 'dougcrew@gmail.com'
        LIMIT 1
    ];
    Id oweaId = owes.isEmpty() ? null : owes[0].Id;


        List<Messaging.SingleEmailMessage> outbox = new List<Messaging.SingleEmailMessage>();

        for (Event eventRecord : upcomingEvents) {

             // only send if the owner is a User
        if (eventRecord.OwnerId == null || !String.valueOf(eventRecord.OwnerId).startsWith('005')){continue;} 

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        if (oweaId != null) mail.setOrgWideEmailAddressId(oweaId); 
            mail.setTargetObjectId(eventRecord.OwnerId);   // send to owner (User)
            mail.setSaveAsActivity(false);
            mail.setSubject('You have an upcoming interview');
            String body = buildEventEmailBody(eventRecord);
            mail.setHtmlBody(body);

            System.debug('Recipient (OwnerId): ' + eventRecord.OwnerId);
            System.debug('Body: ' + body);

            outbox.add(mail);
        }

        if (!outbox.isEmpty()) {
            System.debug(LoggingLevel.WARN, 'About to send ' + outbox.size() + ' reminder(s).');

            Messaging.SendEmailResult[] res = Messaging.sendEmail(outbox);

            // Log per-message success/errors
            for (Integer i = 0; i < res.size(); i++) {
                Messaging.SendEmailResult r = res[i];
                if (r.isSuccess()) {
                    System.debug(LoggingLevel.INFO, 'Email ' + i + ' sent OK.');
                } else {
                    for (Messaging.SendEmailError err : r.getErrors()) {
                        System.debug(LoggingLevel.ERROR,
                            'Email ' + i + ' failed: ' + err.getStatusCode() + ' - ' + err.getMessage());
                    }
                }
            }
        }
    }

    // Build the email body
    private static String buildEventEmailBody(Event eventRecord) {
        String emailBody = '<html><body>';

        emailBody += '<h2>Event Details</h2>';
        emailBody += '<p><strong>Event Name:</strong> ' + html(eventRecord.Subject) + '</p>';
        emailBody += '<p><strong>Contact:</strong> ' + html(String.valueOf(eventRecord.WhoId)) + '</p>';

        if (eventRecord.StartDateTime != null) {
            emailBody += '<p><strong>Date:</strong> ' + eventRecord.StartDateTime.format('MM/dd/yyyy') + '</p>';
            String endStr = eventRecord.EndDateTime != null ? eventRecord.EndDateTime.format('h:mm a') : '';
            emailBody += '<p><strong>Time:</strong> ' + eventRecord.StartDateTime.format('h:mm a') + ' - ' + endStr + '</p>';
        }

        if (eventRecord.Location != null && eventRecord.Location != 'Remote') {
            emailBody += '<p><strong>Location:</strong> ' + html(eventRecord.Location) + '</p>';
        } else {
            if (eventRecord.MeetingLink__c != null) {
                emailBody += '<p><strong>Meeting Link:</strong> ' + html(String.valueOf(eventRecord.MeetingLink__c)) + '</p>';
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
        return s.replace('&','&amp;').replace('<','&lt;').replace('>','&gt;')
                .replace('"','&quot;').replace('\'','&#39;');
    }
}
