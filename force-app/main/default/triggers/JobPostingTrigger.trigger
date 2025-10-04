trigger JobPostingTrigger on Job_Posting__c (before insert) {

    JobPostingTriggerHandler handler = new JobPostingTriggerHandler();
    handler.run(); 
    
}