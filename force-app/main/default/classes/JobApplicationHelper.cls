public with sharing class JobApplicationHelper {


    // BEFORE_INSERT

    public static void setStatusToSaved(List<Job_Application__c> newJobApps){
        for (Job_Application__c app : newJobApps){
            app.Status__c = 'Saved'; // 
        }
    }

    // AFTER INSERT

    public static void savedStatusTasks(List<Job_Application__c> newJobApps){

        List<Task> newTasks = new List<Task>();

        for(Job_Application__c app : newJobApps){

            Task tsk1 = new Task();
            tsk1.Subject = 'Check if the job description aligns with your interests and values';
            tsk1.WhatId = app.Id;
            tsk1.OwnerId = app.Applicant__c;
            tsk1.ActivityDate = Date.today().addDays(2);
            newTasks.add(tsk1);

            Task tsk2 = new Task();
            tsk2.Subject = 'Review the highlighted skills to see if the role is a good fit';
            tsk2.WhatId = app.Id;
            tsk2.OwnerId = app.Applicant__c;
            tsk2.ActivityDate = Date.today().addDays(2);
            newTasks.add(tsk2);

            Task tsk3 = new Task();
            tsk3.Subject = 'Research the company or role and mark your excitement level';
            tsk3.WhatId = app.Id;
            tsk3.OwnerId = app.Applicant__c;
            tsk3.ActivityDate = Date.today().addDays(2);
            newTasks.add(tsk3);
        }
        insert newTasks;
    }

    //BEFORE_UPDATE

    //AFTER_UPDATE

    //BEFORE_DELETE

    //AFTER_DELETE

    //AFTER_UNDELETE


}