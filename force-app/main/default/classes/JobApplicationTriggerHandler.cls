public with sharing class JobApplicationTriggerHandler extends TriggerHandler { 

    private List<Job_Application__c> newJobAppsList;
    private Map<Id, Job_Application__c> newJobAppsMap;
    private List<Job_Application__c> oldJobAppsList;
    private Map<Id, Job_Application__c> oldJobAppsMap;

    public JobApplicationTriggerHandler(){
        this.newJobAppsList = (List<Job_Application__c>)Trigger.new;
        this.newJobAppsMap = (Map<Id,Job_Application__c>)Trigger.newMap;
        this.oldJobAppsList = (List<Job_Application__c>)Trigger.old;
        this.oldJobAppsMap = (Map<Id,Job_Application__c>)Trigger.oldMap;
    }

    public override void beforeInsert(){ 

        JobApplicationHelper.setStatusToSaved(newJobAppsList);
        JobApplicationHelper.checkValueForApplicantAndPosting(newJobAppsList);
        JobApplicationHelper.setApplicationDate(newJobAppsList);

    }

    public override void afterInsert(){
        
        JobApplicationHelper.savedStatusTasks(newJobAppsList);
        JobApplicationHelper.setPrimaryContact(newJobAppsList);
        
    }

    public override void beforeUpdate(){ 
        
        JobApplicationHelper.preventStatusReversal(oldJobAppsMap, newJobAppsList);
        
    } 

    public override void afterUpdate(){ 
        
        JobApplicationHelper.statusTasks(oldJobAppsMap, newJobAppsList);
        
    }

    /* public override void beforeDelete(){ 
        
        
    } */

    /* public override void afterDelete(){ 
        
        
    } */

    /* public override void afterUndelete(){ 
        
        
    } */

}