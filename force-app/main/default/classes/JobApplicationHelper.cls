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

                Task tsk1 = new Task();
                tsk1.Subject = 'Check if the job description aligns with your interests and values';
                tsk1.WhatId = app.Id;
                tsk1.OwnerId = app.Applicant__c;
                tsk1.ActivityDate = Date.today().addDays(1);
                newTasks.add(tsk1);

                Task tsk2 = new Task();
                tsk2.Subject = 'Review the highlighted skills to see if the role is a good fit';
                tsk2.WhatId = app.Id;
                tsk2.OwnerId = app.Applicant__c;
                tsk2.ActivityDate = Date.today().addDays(1);
                newTasks.add(tsk2);

                Task tsk3 = new Task();
                tsk3.Subject = 'Research the company or role and mark your excitement level';
                tsk3.WhatId = app.Id;
                tsk3.OwnerId = app.Applicant__c;
                tsk3.ActivityDate = Date.today().addDays(1);
                newTasks.add(tsk3);
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
        }
    }


    //AFTER_UPDATE

    // Status = APPLYING

    public static void applyingStatusTasks(Map<Id, Job_Application__c> oldJobAppsMap, List<Job_Application__c> newJobApps){

        List<Task> newTasks = new List<Task>();

        for (Job_Application__c app : newJobApps) {

            Job_Application__c oldApp = oldJobAppsMap.get(app.Id);

            if (app.Status__c != oldApp.Status__c && oldApp.Status__c == 'Saved' && app.Status__c == 'Applying') {
                
                Task tsk1 = new Task();
                tsk1.Subject = 'Find and research someone who works at the company and add them as a contact';
                tsk1.WhatId = app.Id;
                tsk1.OwnerId = app.Applicant__c;
                tsk1.ActivityDate = Date.today().addDays(1);
                newTasks.add(tsk1);

                Task tsk2 = new Task();
                tsk2.Subject = 'Set up an informational interview to learn more about the role/company';
                tsk2.WhatId = app.Id;
                tsk2.OwnerId = app.Applicant__c;
                tsk2.ActivityDate = Date.today().addDays(2);
                newTasks.add(tsk2);

                Task tsk3 = new Task();
                tsk3.Subject = 'Identify potential referrals to help get your application on the top of the pile';
                tsk3.WhatId = app.Id;
                tsk3.OwnerId = app.Applicant__c;
                tsk3.ActivityDate = Date.today().addDays(1);
                newTasks.add(tsk3);

                Task tsk4 = new Task();
                tsk4.Subject = 'Customize your work achievements using the job description keywords';
                tsk4.WhatId = app.Id;
                tsk4.OwnerId = app.Applicant__c;
                tsk4.ActivityDate = Date.today().addDays(1);
                newTasks.add(tsk4);

                Task tsk5 = new Task();
                tsk5.Subject = 'Submit your application on the company website if possible';
                tsk5.WhatId = app.Id;
                tsk5.OwnerId = app.Applicant__c;
                tsk5.ActivityDate = Date.today().addDays(2);
                newTasks.add(tsk5);
            }
        }
        if (!newTasks.isEmpty()) {
            insert newTasks;
        }
    }

    // Status = APPLIED

    public static void appliedStatusTasks(Map<Id, Job_Application__c> oldJobAppsMap, List<Job_Application__c> newJobApps){

        List<Task> newTasks = new List<Task>();

        for (Job_Application__c app : newJobApps) {

            Job_Application__c oldApp = oldJobAppsMap.get(app.Id);

            if (app.Status__c != oldApp.Status__c && oldApp.Status__c == 'Applying' && app.Status__c == 'Applied') {

                Task tsk1 = new Task();
                tsk1.Subject = 'Reach out to the hiring manager or recruiter';
                tsk1.WhatId = app.Id;
                tsk1.OwnerId = app.Applicant__c;
                tsk1.ActivityDate = Date.today().addDays(1);
                newTasks.add(tsk1);

                Task tsk2 = new Task();
                tsk2.Subject = 'Follow up on your application via email weekly';
                tsk2.WhatId = app.Id;
                tsk2.OwnerId = app.Applicant__c;
                tsk2.ActivityDate = Date.today().addDays(7);
                newTasks.add(tsk2);

                Task tsk3 = new Task();
                tsk3.Subject = 'Continue identifying and saving similar job opportunities';
                tsk3.WhatId = app.Id;
                tsk3.OwnerId = app.Applicant__c;
                tsk3.ActivityDate = Date.today().addDays(1);
                newTasks.add(tsk3);

                Task tsk4 = new Task();
                tsk4.Subject = 'Set up weekly networking calls to explore similar companies/roles';
                tsk4.WhatId = app.Id;
                tsk4.OwnerId = app.Applicant__c;
                tsk4.ActivityDate = Date.today().addDays(7);
                newTasks.add(tsk4);
            }
        }
        if (!newTasks.isEmpty()) {
            insert newTasks;
        }
    }

    // Status = INTERVIEWING

    public static void interviewingStatusTasks(Map<Id, Job_Application__c> oldJobAppsMap, List<Job_Application__c> newJobApps){

        List<Task> newTasks = new List<Task>();

        for (Job_Application__c app : newJobApps) {

            Job_Application__c oldApp = oldJobAppsMap.get(app.Id);

            if (app.Status__c != oldApp.Status__c && oldApp.Status__c == 'Applied' && app.Status__c == 'Interviewing') {

                Task tsk1 = new Task();
                tsk1.Subject = 'Prepare your blurb or “tell me about yourself” response';
                tsk1.WhatId = app.Id;
                tsk1.OwnerId = app.Applicant__c;
                tsk1.ActivityDate = Date.today().addDays(1);
                newTasks.add(tsk1);

                Task tsk2 = new Task();
                tsk2.Subject = 'Practice answering behavioral interview questions';
                tsk2.WhatId = app.Id;
                tsk2.OwnerId = app.Applicant__c;
                tsk2.ActivityDate = Date.today().addDays(2);
                newTasks.add(tsk2);

                Task tsk3 = new Task();
                tsk3.Subject = 'Research the company and your interviewers';
                tsk3.WhatId = app.Id;
                tsk3.OwnerId = app.Applicant__c;
                tsk3.ActivityDate = Date.today().addDays(1);
                newTasks.add(tsk3);

                Task tsk4 = new Task();
                tsk4.Subject = 'Set up your virtual interview space and test your tech';
                tsk4.WhatId = app.Id;
                tsk4.OwnerId = app.Applicant__c;
                tsk4.ActivityDate = Date.today().addDays(1);
                newTasks.add(tsk4);

                Task tsk5 = new Task();
                tsk5.Subject = 'Send thank you emails within 24 hours';
                tsk5.WhatId = app.Id;
                tsk5.OwnerId = app.Applicant__c;
                tsk5.ActivityDate = Date.today().addDays(1);
                newTasks.add(tsk5);
            }
        }
        if (!newTasks.isEmpty()) {
            insert newTasks;
        }
    }

    // Status = NEGOTIATING

    public static void negotiatingStatusTasks(Map<Id, Job_Application__c> oldJobAppsMap, List<Job_Application__c> newJobApps){

        List<Task> newTasks = new List<Task>();

        for (Job_Application__c app : newJobApps) {

            Job_Application__c oldApp = oldJobAppsMap.get(app.Id);

            if (app.Status__c != oldApp.Status__c && oldApp.Status__c == 'Interviewing' && app.Status__c == 'Negotiating') {

                Task tsk1 = new Task();
                tsk1.Subject = 'Research your market value and know your numbers';
                tsk1.WhatId = app.Id;
                tsk1.OwnerId = app.Applicant__c;
                tsk1.ActivityDate = Date.today().addDays(1);
                newTasks.add(tsk1);

                Task tsk2 = new Task();
                tsk2.Subject = 'Prepare your negotiation scripts';
                tsk2.WhatId = app.Id;
                tsk2.OwnerId = app.Applicant__c;
                tsk2.ActivityDate = Date.today().addDays(2);
                newTasks.add(tsk2);

                Task tsk3 = new Task();
                tsk3.Subject = 'Evaluate your offer and decline or accept';
                tsk3.WhatId = app.Id;
                tsk3.OwnerId = app.Applicant__c;
                tsk3.ActivityDate = Date.today().addDays(1);
                newTasks.add(tsk3);
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
    
}