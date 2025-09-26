public with sharing class JobPostingTriggerHandler extends TriggerHandler{

    private List<Job_Posting__c> newJobPostingList;
    private Map<Id, Job_Posting__c> newJobPostingMap;
    private List<Job_Posting__c> oldJobPostingList;
    private Map<Id, Job_Posting__c> oldJobPostingMap;

    public JobPostingTriggerHandler(){
        this.newJobPostingList = (List<Job_Posting__c>)Trigger.new;
        this.newJobPostingMap = (Map<Id,Job_Posting__c>)Trigger.newMap;
        this.oldJobPostingList = (List<Job_Posting__c>)Trigger.old;
        this.oldJobPostingMap = (Map<Id,Job_Posting__c>)Trigger.oldMap;
    }

    public override void beforeInsert() { 

        JobPostingTriggerHelper.matchAndCreateAccounts(newJobPostingList);
        
    }
}