trigger JobApplicationTrigger on Job_Application__c (before insert, after insert,
                                                     before update, after update) {

    JobApplicationTriggerHandler handler = new JobApplicationTriggerHandler();
    handler.run(); 

}
