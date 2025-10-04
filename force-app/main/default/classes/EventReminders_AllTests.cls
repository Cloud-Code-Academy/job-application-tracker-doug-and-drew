@IsTest
private class EventReminders_AllTests {

    // Build an in-memory Event owned by the running user (no inserts -> no validations)
    private static Event memEvent(String subject, Integer offsetMinutes) {
        Datetime start = Datetime.now().addMinutes(60 + offsetMinutes);
        return new Event(
            Subject       = subject,
            StartDateTime = start,
            EndDateTime   = start.addMinutes(60),
            OwnerId       = UserInfo.getUserId()
        );
    }

    // 1) Service unit test (synchronous)
    @IsTest
    static void service_sends_once_with_multiple_messages() {
        System.assert(String.valueOf(UserInfo.getUserId()).startsWith('005'),
            'Running user must be a User (Id starts with 005).');

        List<Event> events = new List<Event>{
            memEvent('Interview A', 0),
            memEvent('Interview B', 65),
            memEvent('Interview C', 130)
        };

        Test.startTest();
        EventEmailService.sendEventReminder(events);
        Test.stopTest();

        // Assert our own, same-transaction metrics
        System.assertNotEquals(null, EventEmailService.lastOutbox, 'Outbox snapshot should be set.');
        System.assertEquals(3, EventEmailService.lastOutbox.size(), 'Outbox list should have 3 messages.');
        System.assertEquals(3, EventEmailService.lastOutboxSize, 'Outbox size counter should be 3.');
        System.assertEquals(1, EventEmailService.timesSendCalled, 'sendEmail should have been called once.');

        for (Messaging.SingleEmailMessage m : EventEmailService.lastOutbox) {
        System.assertEquals(UserInfo.getUserId(), m.getTargetObjectId(), 'Each email should target the running user.');
        System.assert(!String.isBlank((String)m.getHtmlBody()), 'Email body should not be blank.');
        }
        }

    // 2) Batch test without async (call execute directly)
    @IsTest
    static void batch_execute_calls_service_synchronously() {
        List<SObject> scope = new List<SObject>{
            memEvent('Interview D', 0),
            memEvent('Interview E', 65)
        };

        Test.startTest();
        new EventsBatch().execute(null, scope);
        Test.stopTest();

        System.assertEquals(2, EventEmailService.lastOutboxSize,
            'Outbox should contain 2 messages from batch execute.');
        System.assertEquals(1, EventEmailService.timesSendCalled,
            'sendEmail should have been called once.');
    }

    // 3) Scheduler smoke test (async boundary → no per-transaction assertions)
    @IsTest
    static void scheduler_enqueues_batch() {
        Test.startTest();
        String jobId = System.schedule(
            'EventReminderTestJob',
            '0 0 0 1 1 ? 2099', // any valid cron; in tests it runs at Test.stopTest()
            new EventReminderScheduler()
        );
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Scheduler should return a job id.');

        // Optional: prove a batch ran (don’t assert counts)
        List<AsyncApexJob> jobs = [
            SELECT Id, ApexClass.Name, Status, JobType
            FROM AsyncApexJob
            WHERE ApexClass.Name IN ('EventsBatch', 'EventReminderScheduler')
        ];
        System.assert(!jobs.isEmpty(), 'Expected at least one async job (batch or scheduler).');
    }
}
