public with sharing class EventEmailService {

     @TestVisible private static Integer lastOutboxSize;
    @TestVisible private static Integer timesSendCalled;
    @TestVisible private static List<Messaging.SingleEmailMessage> lastOutbox; // ← add

    public static void sendEventReminder(List<Event> upcomingEvents) {
        // clear per invocation
        lastOutboxSize = null;
        timesSendCalled = 0;
        lastOutbox = null; // ← add

        if (upcomingEvents == null || upcomingEvents.isEmpty()) return;

        List<Messaging.SingleEmailMessage> outbox = new List<Messaging.SingleEmailMessage>();

        for (Event eventRecord : upcomingEvents) {
            if (eventRecord.OwnerId == null || !String.valueOf(eventRecord.OwnerId).startsWith('005')) continue;

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(eventRecord.OwnerId);
            mail.setSaveAsActivity(false);
            mail.setSubject('You have an upcoming interview');
            String body = buildEventEmailBody(eventRecord);
            mail.setHtmlBody(body);
            outbox.add(mail);
        }

        if (!outbox.isEmpty()) {
            // set test-visible metrics BEFORE sending
            lastOutboxSize = outbox.size();
            lastOutbox     = outbox;            // ← add

            System.debug(LoggingLevel.WARN, 'About to send ' + outbox.size() + ' reminder(s).');

            Messaging.SendEmailResult[] res = Messaging.sendEmail(outbox);
            timesSendCalled++;
            // ... (rest unchanged)
        }
    }

    // Build email body
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
