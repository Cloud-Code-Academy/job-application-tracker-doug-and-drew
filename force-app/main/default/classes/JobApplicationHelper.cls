public with sharing class JobApplicationHelper {

    // --- Single source of truth for status order (lower = earlier in the process)
    private static final Map<String, Integer> STATUS_ORDER = new Map<String, Integer>{
        'Saved' => 0,
        'Applying' => 1, 
        'Applied' => 2,
        'Interviewing' => 3,
        'Negotiating' => 4,
        'Accepted' => 5,
        'Closed' => 6
    };

    // Statuses that cannot be changed once reached
    private static final Set<String> TERMINAL_STATUSES = new Set<String>{
        'Accepted', 'Closed'
    };

    // Map to contain Custom Metadata templates if needed
    private static Map<String, List<Job_Application_Task_Template__mdt>> templatesByStatus;

    // BEFORE_INSERT

    // Sets the Status to Saved.
    public static void setStatusToSaved(List<Job_Application__c> newJobApps) {
        for (Job_Application__c app : newJobApps){

            if (!String.isBlank(app.Status__c) && app.Status__c != 'Saved') {
                app.addError('Status must be either left blank or set to Saved');
            } else if (String.isBlank(app.Status__c)) {
                app.Status__c = 'Saved'; 
            }
             
        }
    }

    // Validate that the record has an Applicant and Job Posting.
    public static void checkValueForApplicantAndPosting(List<Job_Application__c> newJobApps){
        for (Job_Application__c app : newJobApps){

            if (app.Applicant__c == null) {
                app.addError('An Applicant is required');
            }
            if (app.Job_Posting__c == null) {
                app.addError('A Job Posting is required');
            }
        }
    }

    // If Application is null, set the date to today's date
    public static void setApplicationDate(List<Job_Application__c> newJobApps) {
        for (Job_Application__c app : newJobApps) {

            if (app.Application_Date__c == null) {
                app.Application_Date__c = Date.Today();
            }
        }
    }

    // AFTER INSERT

    // Assigns the Primary Contact if a Contact is related to the Account/Company.
    public static void setPrimaryContact(List<Job_Application__c> newJobApps){

        if (newJobApps == null || newJobApps.isEmpty()) {
            return;
        }
        // Get Job Application Ids
        Set<Id> appIds = new Set<Id>();
        for (Job_Application__c app : newJobApps) {
            if (app.Id != null) {
                appIds.add(app.Id);
            }
        }
        if (appIds.isEmpty()) {
            return;
        }
        // Get Job Applications that already have a primary Application Contact and skip them.
        // These should not exist with the current process, but is a safety check
        Set<Id> appsWithPrimaryContact = new Set<Id>();
        for (Application_Contact__c ac : [SELECT Id, Job_Application__c
                                          FROM Application_Contact__c
                                          WHERE Job_Application__c IN : appIds
                                          AND Is_Primary__c = true]
            ) {
                appsWithPrimaryContact.add(ac.Job_Application__c);
            }
        // Set for Job Application Ids that still require a Primary Contact
        Set<Id> appsWithoutPrimaryContact = new Set<Id>();
        // if the appId does not exist in the appsWithPrimaryContact Set, then add it to the
        // appsWithoutPrimaryContact Set to identify which apps still require a Primary Contact
        for (Id appId : appIds) {
            if (!appsWithPrimaryContact.contains(appId)) {
                appsWithoutPrimaryContact.add(appId);
            }
        }
        if (appsWithoutPrimaryContact.isEmpty()) {
            return;
        }
        // Map the remaining Job Application Ids to their respective Account Ids from the Job Posting
        Map<Id, Id> jobAppIdToAccountId = new Map<Id, Id>(); // Job Application Id -> Account Id
        Set<Id> accountIds = new Set<Id>();
        for (Job_Application__c jobApp : [SELECT Id, Job_Posting__r.Company_Name__c
                                          FROM Job_Application__c
                                          WHERE Id IN : appsWithoutPrimaryContact]
        ) {
            Id acctId = (jobApp.Job_Posting__r == null) ? null : jobApp.Job_Posting__r.Company_Name__c;
            if (acctId != null) {
                jobAppIdToAccountId.put(jobApp.Id, acctId);
                accountIds.add(acctId);
                }
            }
        if (accountIds.isEmpty()) {
                return;
            }
        // Choose one Contact per Account by Created Date (newest)
        Map<Id, Contact> accountToContact = new Map<Id, Contact>(); //Account Id -> Contact Id
        for (Contact con : [SELECT Id, AccountId 
                            FROM Contact
                            WHERE AccountId IN : accountIds
                            ORDER BY CreatedDate DESC, Id DESC]
        )  {
            if (!accountToContact.containsKey(con.AccountId)) {
                accountToContact.put(con.AccountId, con);
                }
            }
        if (accountToContact.isEmpty()) {
            return;
        }
        // Create Application Contact records for insertion
        List<Application_Contact__c> appContactsToInsert = new List<Application_Contact__c>();
        for (Id appId : appsWithoutPrimaryContact) {
            Id acctId = jobAppIdToAccountId.get(appId);
            if (acctId == null) {
                continue;
            }
            Contact selectedContact = accountToContact.get(acctId);
            if (selectedContact == null) {
                continue;
            }
            appContactsToInsert.add(new Application_Contact__c(
                Job_Application__c = appId,
                Contact__c = selectedContact.Id,
                Is_Primary__c = true
            ));
        }
        if(!appContactsToInsert.isEmpty()) {
            insert appContactsToInsert;
        }
    }

    // Creates the first 3 tasks when a Job Application record is created and in Saved Status.
    public static void savedStatusTasks(List<Job_Application__c> newJobApps){

        List<Task> newTasks = new List<Task>();

        for (Job_Application__c app : newJobApps) {

            if (app.Status__c == 'Saved') {

                newTasks.addAll(buildTasksFromTemplates(app));
            }
        }
        if (!newTasks.isEmpty()) {
            insert newTasks;
        }
    }

    //BEFORE_UPDATE

    // Prevent the Status from being moved backwards

    public static void preventStatusReversal(Map<Id, Job_Application__c> oldJobAppsMap, List<Job_Application__c> newJobApps){

        if (newJobApps == null || newJobApps.isEmpty() || oldJobAppsMap == null) {
            return;
        }

        for (Job_Application__c app : newJobApps) {

            Job_Application__c oldApp = oldJobAppsMap.get(app.Id);

            if (oldApp == null) {
                continue;
            }

            String oldStatus = oldApp.Status__c;
            String newStatus = app.Status__c;
            // If no status change occurred, skip the record
            if (oldStatus == newStatus){
                continue;
            }
            // Allow moving status to Closed from any other status
            if (newStatus == 'Closed'){
                continue;
            }
            // Terminal status - do not allow status to be changed from 'Closed' or 'Accepted'
            if (oldStatus != null && TERMINAL_STATUSES.contains(oldStatus)) {
                app.addError('This application is already ' + oldStatus + '. Status cannot be changed.');
                continue;
            }
            
            Integer oldRank = STATUS_ORDER.get(oldStatus);
            Integer newRank = STATUS_ORDER.get(newStatus);
            
            if (oldRank == null || newRank == null) {
                app.addError('Invalid status transition. Please choose a valid status');
            }

            // Prevent status from moving backward
            if (newRank < oldRank) {
                app.addError('Status cannot be moved backward from ' + oldStatus + ' to ' + newStatus + '.');
            }

            // Allow forward status changes by one status only
            if (newRank > oldRank + 1) {
                app.addError('Please move the status one step at a time (from ' + oldStatus + ' to the next stage).');
                continue;
            }
        }
    }


    //AFTER_UPDATE

    public static void statusTasks(Map<Id, Job_Application__c> oldJobAppsMap, List<Job_Application__c> newJobApps){

        List<Task> newTasks = new List<Task>();

        for (Job_Application__c app : newJobApps) {

            Job_Application__c oldApp = oldJobAppsMap.get(app.Id);

            if (oldApp == null) {
                continue;
            }

            if (app.Status__c != oldApp.Status__c) {
                
                newTasks.addAll(buildTasksFromTemplates(app));

            }
        }
        if (!newTasks.isEmpty()) {
            insert newTasks;
        }
    }

    //BEFORE_DELETE

    //AFTER_DELETE

    //AFTER_UNDELETE

    // Helper Methods:

    // Retrieve(Lazy-load) all active Job_Application_Task_Template__mdt Templates once.
    // Sort the templates using a Map where the Key = Status and Value = List of Templates 
    private static void loadTaskTemplatesIfNeeded() {
        if (templatesByStatus != null) {
            return;
        }

        templatesByStatus = new Map<String, List<Job_Application_Task_Template__mdt>>();

        // One SOQL for all templates
        List<Job_Application_Task_Template__mdt> templateList = [
            SELECT Status__c, Subject__c, DaysOffset__c, Priority__c, Sort_Order__c, DeveloperName
            FROM Job_Application_Task_Template__mdt
            WHERE Active__c = true
            ORDER BY Status__c ASC, Sort_Order__c ASC, DeveloperName ASC
        ];
        // for each template, we add the template to the list of templates in the map, with the key being the status of the template
        for (Job_Application_Task_Template__mdt template : templateList) {
            List<Job_Application_Task_Template__mdt> bucket = templatesByStatus.get(template.Status__c);
            // If this is the first template in the status list(bucket) then we create a new list.
            // adding the null check prevents NPE for the first item by status
            // there will be a bucket list for every status listed in the templates
            if (bucket == null) {
                bucket = new List<Job_Application_Task_Template__mdt>();
                templatesByStatus.put(template.Status__c, bucket);
            }
            // there is no need to use the put function for the map, as we are adding each template to the corresponding list(value) within
            // the map to the corresponding status(key)
            bucket.add(template);
        }
    }

    // Get Job_Application_Task_Template__mdt Templates for a specific status
    private static List<Job_Application_Task_Template__mdt> templatesForStatus(String status) {
        // Call the method to query and sort all the templates into a Map by Status
        loadTaskTemplatesIfNeeded();
        //Create a list to filter only the templates needed for the status in the argument
        List<Job_Application_Task_Template__mdt> bucket = templatesByStatus.get(status);
        // If the bucket is null return an empty list, else return the list of templates
        return (bucket == null) ? new List<Job_Application_Task_Template__mdt>() : bucket;
    }

    // Task Builder from mdt templates, based on the current status of the Job Application
    public static List<Task> buildTasksFromTemplates(Job_Application__c app) {
        List<Task> output = new List<Task>();
        if (app == null || app.Id == null || String.isBlank(app.Status__c) || app.Applicant__c == null) {
            return output; // nothing to return / protects against bad inputs
        }
        // iterate through the templates to create tasks.  templatesForStatus method can be called in the header
        // to create the list of templates based on app status.
        for (Job_Application_Task_Template__mdt template : templatesForStatus(app.Status__c)) {
            Integer offset = (template.DaysOffset__c == null) ? 0 : (Integer)template.DaysOffset__c;
            Task tsk = new Task(
                WhatId = app.Id,
                OwnerId = app.Applicant__c,
                Subject = template.Subject__c,
                ActivityDate = Date.today().addDays(offset)
            );
            if (!String.isBlank(template.Priority__c)) {
                tsk.Priority = template.Priority__c;
            }
            output.add(tsk);
        }
        return output;
    }
    
}