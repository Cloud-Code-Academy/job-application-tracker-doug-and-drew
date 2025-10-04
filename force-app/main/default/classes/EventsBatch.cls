public with sharing class EventsBatch implements  Database.Batchable<SObject> {
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([SELECT Id, WhatId, WhoId, Subject, StartDateTime, EndDateTime, MeetingLink__c, Location, OwnerId, Owner.Email, Description
                                     FROM Event 
                                     WHERE StartDateTime > :System.now() 
                                     AND StartDateTime < :System.now().addhours(25) 
                                     AND IsAllDayEvent = false]);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<Event> eventsScope = (List<Event>)scope;
         System.debug('Batch execute method called scope size: ' + scope.size());

         if (!eventsScope.isEmpty()) {
            EventEmailService.sendEventReminder(eventsScope);
            }
        }


    public void finish(Database.BatchableContext bc) {
        System.debug('EventsBatch finished sending reminders.');     
    }
}
