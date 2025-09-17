trigger JobApplicationTrigger on Job_Application__c (before insert, after insert) {

    JobApplicationTriggerHandler handler = new JobApplicationTriggerHandler();
    handler.run(); 

}
