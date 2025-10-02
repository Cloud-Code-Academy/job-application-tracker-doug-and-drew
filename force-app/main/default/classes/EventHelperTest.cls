@isTest
public with sharing class EventHelperTest {
    
    // =====================================
    // BEFORE INSERT TESTS
    // =====================================

    // Utility: Always return a weekday
    private static Date nextWeekday(Date d) {
        while (EventHelper.isWeekend(d)) {
            d = d.addDays(1);
        }
        return d;
    }

    @isTest
    static void testInsertValidEvent_success() {
        // Arrange: Create a valid Event that does not violate rules
        Event e = new Event(
            OwnerId = UserInfo.getUserId(),
            StartDateTime = Datetime.newInstance(2025, 10, 1, 9, 0, 0), // Wednesday morning
            EndDateTime   = Datetime.newInstance(2025, 10, 1, 10, 0, 0), // 1 hour later
            Subject = 'Valid Test Event'
        );
        
        // Act: Attempt to insert inside a test context
        Test.startTest();
        insert e;
        Test.stopTest();
        
        // Assert: Query back to ensure it saved correctly
        Event savedEvent = [SELECT Id, Subject FROM Event WHERE Id = :e.Id];
        System.assertNotEquals(null, savedEvent, 'The event should have been inserted successfully.');
        System.assertEquals('Valid Test Event', savedEvent.Subject, 'The event subject should match.');
    }

    @isTest
    static void testInsertWeekendEvent_blocked() {
        // Arrange: Create an Event on a Saturday (Oct 4, 2025 is a Saturday)
        Event weekendEvent = new Event(
            OwnerId = UserInfo.getUserId(),
            StartDateTime = Datetime.newInstance(2025, 10, 4, 9, 0, 0),  // Saturday
            EndDateTime   = Datetime.newInstance(2025, 10, 4, 10, 0, 0), // Same morning
            Subject = 'Weekend Event'
        );

        // Act: Try to insert with partial success allowed
        Test.startTest();
        Database.SaveResult sr = Database.insert(weekendEvent, false); 
        Test.stopTest();

        // Assert: The insert should fail, and the error message should mention weekends
        System.assertEquals(false, sr.isSuccess(), 'Weekend events should not be allowed.');
        System.assert(sr.getErrors()[0].getMessage().contains('weekends'),
            'Expected error message about weekends, but got: ' + sr.getErrors()[0].getMessage());
    }

    @isTest
    static void testInsertEmptyList_noProcessing() {
        // Act: Call helper directly with an empty list
        Test.startTest();
        EventHelper.beforeInsert(new List<Event>()); 
        Test.stopTest();

        // Assert: Nothing should blow up (this is mainly for coverage)
        System.assert(true, 'Empty list should safely exit without errors.');
    }

    @isTest
    static void testInsertMissingStart_blocked() {
        // Arrange: Missing start datetime
        Event noStartDate = new Event(
            OwnerId = UserInfo.getUserId(),
            EndDateTime = Datetime.newInstance(2025, 10, 1, 10, 0, 0),
            Subject = 'Missing Start Date'
        );

        // Act: Try to insert
        Test.startTest();
        Database.SaveResult sr = Database.insert(noStartDate, false);
        Test.stopTest();

        // Assert: Should fail with "Start time is required" error
        System.assertEquals(false, sr.isSuccess(), 'Start time is required');
        System.assert(sr.getErrors()[0].getMessage().contains('Start time is required'),
            'Expected error about the required field, but got: ' + sr.getErrors()[0].getMessage());
    }

    @isTest
    static void testInsertMissingEnd_blocked() {
        // Arrange: Missing end datetime
        Event noEndDate = new Event(
            OwnerId = UserInfo.getUserId(),
            StartDateTime = Datetime.newInstance(2025, 10, 1, 10, 0, 0),
            Subject = 'Missing End Date'
        );

        // Act: Try to insert
        Test.startTest();
        Database.SaveResult sr = Database.insert(noEndDate, false);
        Test.stopTest();

        // Assert: Should fail with "End time is required" error
        System.assertEquals(false, sr.isSuccess(), 'End time is required');
        System.assert(sr.getErrors()[0].getMessage().contains('End time is required'),
            'Expected error about the required field, but got: ' + sr.getErrors()[0].getMessage());
    }

    @isTest
    static void testInsertOverlapWithExistingEvent_blocked() {
        // Arrange: Create an existing Event in the database
        Event existing = new Event(
            OwnerId = UserInfo.getUserId(),
            StartDateTime = Datetime.newInstance(2025, 10, 2, 9, 0, 0), // Thursday 9 AM
            EndDateTime   = Datetime.newInstance(2025, 10, 2, 10, 0, 0), // 10 AM
            Subject = 'Existing Event'
        );
        insert existing;

        // Arrange: Create a new Event that overlaps with the existing one
        Event overlapping = new Event(
            OwnerId = UserInfo.getUserId(),
            StartDateTime = Datetime.newInstance(2025, 10, 2, 9, 30, 0), // 9:30 AM (inside existing window)
            EndDateTime   = Datetime.newInstance(2025, 10, 2, 10, 30, 0), // 10:30 AM
            Subject = 'Overlapping Event'
        );

        // Act: Try to insert the overlapping Event
        Test.startTest();
        Database.SaveResult sr = Database.insert(overlapping, false);
        Test.stopTest();

        // Assert: Should fail with overlap error
        System.assertEquals(false, sr.isSuccess(), 'Overlapping events should not be allowed.');
        System.assert(sr.getErrors()[0].getMessage().contains('overlaps with an existing event'),
            'Expected overlap error, but got: ' + sr.getErrors()[0].getMessage());
    }

    @isTest
    static void testInsertAllDayEvent_success() {
        // Arrange: All-day event with ActivityDate set
        Event allDayEvent = new Event(
            OwnerId = UserInfo.getUserId(),
            IsAllDayEvent = true,
            ActivityDate = Date.newInstance(2025, 10, 1), // Wednesday
            Subject = 'Valid All-Day Event'
        );

        // Act: Insert should succeed
        Test.startTest();
        insert allDayEvent;
        Test.stopTest();

        // Assert: Query back to confirm it saved successfully
        Event savedEvent = [SELECT Id, IsAllDayEvent, ActivityDate 
                            FROM Event 
                            WHERE Id = :allDayEvent.Id];
        System.assertNotEquals(null, savedEvent, 'All-day event should save successfully.');
        System.assertEquals(true, savedEvent.IsAllDayEvent, 'Event should be flagged as all-day.');
        System.assertEquals(Date.newInstance(2025, 10, 1), savedEvent.ActivityDate, 'ActivityDate should be set correctly.');
    }

    @isTest
    static void testInsertAllDayEventNoDate_blocked() {
        // Arrange: All-day event with no ActivityDate
        Event badAllDayEvent = new Event(
            OwnerId = UserInfo.getUserId(),
            IsAllDayEvent = true,
            Subject = 'Invalid All-Day Event'
        );

        // Act: Try to insert
        Test.startTest();
        Database.SaveResult sr = Database.insert(badAllDayEvent, false);
        Test.stopTest();

        // Assert: Should fail with error about missing values
        System.assertEquals(false, sr.isSuccess(), 'All-day event without ActivityDate should not save.');
        System.assert(sr.getErrors()[0].getMessage().contains('For all-day events'),
            'Expected error about missing ActivityDate, but got: ' + sr.getErrors()[0].getMessage());
    }

    // =====================================
    // BEFORE UPDATE TESTS
    // =====================================

    @isTest
    static void testUpdateEmptyInputs_noProcessing() {
        Test.startTest();
        EventHelper.beforeUpdate(new Map<Id, Event>(), new List<Event>()); 
        Test.stopTest();

        System.assert(true, 'Empty inputs should safely exit without errors.');
    }
    
    @isTest
    static void testUpdateEventNoScheduleChange_success() {
        // Arrange: Insert an Event first
        Event e = new Event(
            OwnerId = UserInfo.getUserId(),
            StartDateTime = Datetime.newInstance(2025, 10, 6, 9, 0, 0),
            EndDateTime   = Datetime.newInstance(2025, 10, 6, 10, 0, 0),
            Description = 'Original Event'
        );
        insert e;

        // Act: Update only non-schedule fields (e.g., Subject)
        e.Description = 'Updated Event Description';
        Test.startTest();
        update e;
        Test.stopTest();

        // Assert: Should succeed
        Event updated = [SELECT Description FROM Event WHERE Id = :e.Id];
        System.assertEquals('Updated Event Description', updated.Description, 'Subject should update without error.');
    }

    @isTest
    static void testUpdateEventWithScheduleChange_overlapBlocked() {
        // Arrange: Insert two events, one fixed and one to be moved
        Event fixed = new Event(
            OwnerId = UserInfo.getUserId(),
            StartDateTime = Datetime.newInstance(2025, 10, 6, 9, 0, 0),
            EndDateTime   = Datetime.newInstance(2025, 10, 6, 10, 0, 0),
            Subject = 'Fixed Event'
        );
        insert fixed;

        Event movable = new Event(
            OwnerId = UserInfo.getUserId(),
            StartDateTime = Datetime.newInstance(2025, 10, 6, 11, 0, 0),
            EndDateTime   = Datetime.newInstance(2025, 10, 6, 12, 0, 0),
            Subject = 'Movable Event'
        );
        insert movable;

        // Act: Move movable Event into overlap with fixed Event
        movable.StartDateTime = Datetime.newInstance(2025, 10, 6, 9, 30, 0);
        movable.EndDateTime   = Datetime.newInstance(2025, 10, 6, 10, 30, 0);

        Test.startTest();
        Database.SaveResult sr = Database.update(movable, false);
        Test.stopTest();

        // Assert: Should fail with overlap error
        System.assertEquals(false, sr.isSuccess(), 'Event should not save when moved into overlap.');
        System.assert(sr.getErrors()[0].getMessage().contains('overlaps with an existing event'),
            'Expected overlap error, but got: ' + sr.getErrors()[0].getMessage());
    }

    @isTest
    static void testUpdateEventWithScheduleChange_valid() {
        // Arrange: Insert an event
        Event e = new Event(
            OwnerId = UserInfo.getUserId(),
            StartDateTime = Datetime.newInstance(2025, 10, 7, 9, 0, 0),
            EndDateTime   = Datetime.newInstance(2025, 10, 7, 10, 0, 0),
            Subject = 'Event to Move'
        );
        insert e;

        // Act: Move event later in the day, no overlaps
        e.StartDateTime = Datetime.newInstance(2025, 10, 7, 14, 0, 0);
        e.EndDateTime   = Datetime.newInstance(2025, 10, 7, 15, 0, 0);

        Test.startTest();
        update e;
        Test.stopTest();

        // Assert: Should succeed
        Event updated = [SELECT StartDateTime, EndDateTime FROM Event WHERE Id = :e.Id];
        System.assertEquals(Datetime.newInstance(2025, 10, 7, 14, 0, 0), updated.StartDateTime, 'Start time should update.');
        System.assertEquals(Datetime.newInstance(2025, 10, 7, 15, 0, 0), updated.EndDateTime, 'End time should update.');
    }

    @isTest
    static void testUpdateMultipleEvents_sameOwnerOverlap_blocked() {
        // Arrange: Insert two non-overlapping events
        Event e1 = new Event(
            OwnerId = UserInfo.getUserId(),
            StartDateTime = Datetime.newInstance(2025, 10, 8, 9, 0, 0),
            EndDateTime   = Datetime.newInstance(2025, 10, 8, 10, 0, 0),
            Subject = 'Event 1'
        );
        Event e2 = new Event(
            OwnerId = UserInfo.getUserId(),
            StartDateTime = Datetime.newInstance(2025, 10, 8, 11, 0, 0),
            EndDateTime   = Datetime.newInstance(2025, 10, 8, 12, 0, 0),
            Subject = 'Event 2'
        );
        insert new List<Event>{ e1, e2 };

        // Act: Move both into overlapping times in the same transaction
        e1.StartDateTime = Datetime.newInstance(2025, 10, 8, 13, 0, 0);
        e1.EndDateTime   = Datetime.newInstance(2025, 10, 8, 14, 0, 0);

        e2.StartDateTime = Datetime.newInstance(2025, 10, 8, 13, 30, 0); // overlaps with e1
        e2.EndDateTime   = Datetime.newInstance(2025, 10, 8, 14, 30, 0);

        Test.startTest();
        Database.SaveResult[] results = Database.update(new List<Event>{ e1, e2 }, false);
        Test.stopTest();

        // Assert: Both should fail
        System.assertEquals(false, results[0].isSuccess(), 'Event 1 should fail due to overlap.');
        System.assertEquals(false, results[1].isSuccess(), 'Event 2 should fail due to overlap.');
    }
   

    // =====================================
    // BULK TESTS
    // =====================================

    @isTest
    static void testBulkInsertMultipleEvents_success() {
        // Arrange: Build a list of 200 non-overlapping events
        List<Event> eventsToInsert = new List<Event>();
        Date d = nextWeekday(Date.newInstance(2025, 10, 6)); // Start Monday, force weekday

        for (Integer i = 0; i < 200; i++) {
            eventsToInsert.add(new Event(
                OwnerId = UserInfo.getUserId(),
                StartDateTime = Datetime.newInstance(d.year(), d.month(), d.day(), 9, 0, 0),
                EndDateTime   = Datetime.newInstance(d.year(), d.month(), d.day(), 10, 0, 0),
                Subject = 'Bulk Event ' + i
            ));
            d = nextWeekday(d.addDays(1)); // Move to next weekday
        }

        // Act
        Test.startTest();
        insert eventsToInsert;
        Test.stopTest();

        // Assert: All 200 should insert successfully
        System.assertEquals(200, [SELECT COUNT() FROM Event WHERE Subject LIKE 'Bulk Event%'],
            'All bulk events should have been inserted.');
    }

    @isTest
    static void testBulkUpdateMixedValidInvalidEvents() {
        Date baseDate = nextWeekday(Date.newInstance(2025, 10, 10));

        Event e1 = new Event(
            OwnerId = UserInfo.getUserId(),
            StartDateTime = Datetime.newInstance(baseDate.year(), baseDate.month(), baseDate.day(), 9, 0, 0),
            EndDateTime   = Datetime.newInstance(baseDate.year(), baseDate.month(), baseDate.day(), 10, 0, 0),
            Subject = 'Bulk Valid 1'
        );
        Event e2 = new Event(
            OwnerId = UserInfo.getUserId(),
            StartDateTime = Datetime.newInstance(baseDate.year(), baseDate.month(), baseDate.day(), 11, 0, 0),
            EndDateTime   = Datetime.newInstance(baseDate.year(), baseDate.month(), baseDate.day(), 12, 0, 0),
            Subject = 'Bulk Invalid'
        );
        Event e3 = new Event(
            OwnerId = UserInfo.getUserId(),
            StartDateTime = Datetime.newInstance(baseDate.year(), baseDate.month(), baseDate.day(), 13, 0, 0),
            EndDateTime   = Datetime.newInstance(baseDate.year(), baseDate.month(), baseDate.day(), 14, 0, 0),
            Subject = 'Bulk Valid 2'
        );
        insert new List<Event>{ e1, e2, e3 };

        // Act: Make e2 overlap e1, while e3 stays valid
        e2.StartDateTime = Datetime.newInstance(baseDate.year(), baseDate.month(), baseDate.day(), 9, 30, 0);
        e2.EndDateTime   = Datetime.newInstance(baseDate.year(), baseDate.month(), baseDate.day(), 10, 30, 0);

        Test.startTest();
        Database.SaveResult[] results = Database.update(new List<Event>{ e1, e2, e3 }, false);
        Test.stopTest();

        System.assertEquals(true, results[0].isSuccess(), 'Event 1 should remain valid.');
        System.assertEquals(false, results[1].isSuccess(), 'Event 2 should fail due to overlap.');
        System.assertEquals(true, results[2].isSuccess(), 'Event 3 should remain valid.');
    }

}
