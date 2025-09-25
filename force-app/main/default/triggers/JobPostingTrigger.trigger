trigger JobPostingTrigger on Job_Posting__c (after insert) {

    JobPostingTriggerHandler handler = new JobPostingTriggerHandler();
    handler.run(); 
    
}