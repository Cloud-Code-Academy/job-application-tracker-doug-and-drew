public with sharing class EventsBatchTest {
    @IsTest
    static void nextStepBatch_testUpdateAllNextStep() {
        // Create test data
        List<Event> testEvents = new List<Events>();
        for (Integer i = 0; i < 5; i++) {
            testEvents.add(new Account(Name = 'Test Account ' + i));
        }
        insert testEvents;

        List<Opportunity> testOpps = new List<Opportunity>();
        for (Account acc : testEvents) {
            testOpps.add(new Opportunity(Name = 'Test Opp for ' + acc.Name, AccountId = acc.Id, CloseDate = Date.today(), StageName = 'Prospecting'));
        }
        insert testOpps;

        // Call the batch class
        Test.startTest();
        NextStepBatch batchJob = new NextStepBatch();
        Id batchId = Database.executeBatch(batchJob);
        Test.stopTest();

        // Query the updated accounts and opportunities
        List<Account> updatedAccounts = [SELECT Id, Next_Step__c FROM Account WHERE Id IN :testEvents];
        List<Opportunity> updatedOpps = [SELECT Id, NextStep FROM Opportunity WHERE Id IN :testOpps];

        // Assert that all account's Next_Step__c fields are updated
        for (Account acc : updatedAccounts) {
            System.assertEquals('Batching the next meetings together.', acc.Next_Step__c, 'Account Next_Step__c field was not updated correctly.');
        }

        // Assert that all opportunity's NextStep fields are updated
        for (Opportunity opp : updatedOpps) {
            System.assertEquals('Batching the next meetings together.', opp.NextStep, 'Opportunity NextStep field was not updated correctly.');
        }
    }
}