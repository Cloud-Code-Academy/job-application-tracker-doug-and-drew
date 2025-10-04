public with sharing class EventReminderScheduler implements Schedulable{

    public void execute (SchedulableContext sc) {
        System.debug('Scheduled Job Started');
        Database.executeBatch(new EventsBatch(), 200);
    }
}