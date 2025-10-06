@isTest
public with sharing class JobApplicationHelperTest {

    // =====================================
    // TEST DATA SETUP
    // =====================================
    @testSetup
    static void setupTestData() {
        // Create an Account
        Account acct = new Account(Name = 'Test Account');
        insert acct;

        // Create a Contact for the Account
        Contact con = new Contact(
            LastName = 'Primary Contact',
            AccountId = acct.Id
        );
        insert con;

        // Create a Job Posting linked to the Account
        Job_Posting__c posting = new Job_Posting__c(
            Company_Name__c = acct.Id,
            Job_Description__c = 'Test Job Description',
            Location__c = 'Remote',
            Title_Position__c = 'Test Developer'
        );
        insert posting;

        // Create a base Job Application (defaults to Saved)
        Job_Application__c app = new Job_Application__c(
            Applicant__c = UserInfo.getUserId(),
            Job_Posting__c = posting.Id
        );
        insert app;
    }

    // =====================================
    // BEFORE INSERT TESTS
    // =====================================

    @isTest
    static void testSetStatusToSaved_success() {
        // Arrange
        Job_Application__c app = new Job_Application__c(
            Applicant__c = UserInfo.getUserId(),
            Job_Posting__c = [SELECT Id FROM Job_Posting__c LIMIT 1].Id
        );

        // Act
        Test.startTest();
        insert app;
        Test.stopTest();

        // Assert
        Job_Application__c inserted = [SELECT Status__c FROM Job_Application__c WHERE Id = :app.Id];
        System.assertEquals('Saved', inserted.Status__c, 'Status should default to Saved if blank.');
    }

    @isTest
    static void testCheckApplicantAndPosting_blocked() {
        // Arrange: Missing both Applicant and Posting
        Job_Application__c app = new Job_Application__c(
            Status__c = 'Saved'
        );

        // Act
        Test.startTest();
        Database.SaveResult sr = Database.insert(app, false);
        Test.stopTest();

        // Assert
        System.assertEquals(false, sr.isSuccess(), 'Record should not insert without Applicant/Posting.');
        System.assert(
            sr.getErrors()[0].getMessage().contains('Applicant') || sr.getErrors()[0].getMessage().contains('Posting'),
            'Expected error about missing Applicant/Posting.'
        );
    }

    @isTest
    static void testSetApplicationDate_success() {
        // Arrange
        Job_Application__c app = new Job_Application__c(
            Applicant__c = UserInfo.getUserId(),
            Job_Posting__c = [SELECT Id FROM Job_Posting__c LIMIT 1].Id
        );

        // Act
        Test.startTest();
        insert app;
        Test.stopTest();

        // Assert
        Job_Application__c inserted = [SELECT Application_Date__c FROM Job_Application__c WHERE Id = :app.Id];
        System.assertEquals(Date.today(), inserted.Application_Date__c,
            'Application date should default to today.');
    }

    // =====================================
    // AFTER INSERT TESTS
    // =====================================

    @isTest
    static void testSetPrimaryContact_success() {
        // Arrange
        Job_Application__c app = [SELECT Id FROM Job_Application__c LIMIT 1];

        // Act
        Test.startTest();
        JobApplicationHelper.setPrimaryContact(new List<Job_Application__c>{ app });
        Test.stopTest();

        // Assert
        Application_Contact__c ac = [
            SELECT Id, Is_Primary__c 
            FROM Application_Contact__c 
            WHERE Job_Application__c = :app.Id 
            LIMIT 1
        ];
        System.assertEquals(true, ac.Is_Primary__c, 'Primary Contact should have been assigned.');
    }

    @isTest
    static void testSavedStatusTasks_createsTasks() {
        // Arrange: use existing CMDT template for Saved
        Job_Application__c app = [SELECT Id, Status__c, Applicant__c FROM Job_Application__c LIMIT 1];

        // Act
        Test.startTest();
        JobApplicationHelper.savedStatusTasks(new List<Job_Application__c>{ app });
        Test.stopTest();

        // Assert
        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :app.Id];
        System.assert(tasks.size() > 0, 'At least one task should have been created from CMDT.');
    }

    // =====================================
    // BEFORE UPDATE TESTS
    // =====================================

    @isTest
    static void testPreventStatusReversal_blocked() {
        // Arrange
        Job_Application__c app = [SELECT Id, Status__c FROM Job_Application__c LIMIT 1];
        app.Status__c = 'Applying';
        update app;
        app.Status__c = 'Applied';
        update app;

        // Act: Try to move backward
        app.Status__c = 'Saved';
        Test.startTest();
        Database.SaveResult sr = Database.update(app, false);
        Test.stopTest();

        // Assert
        System.assertEquals(false, sr.isSuccess(), 'Should not allow moving status backward.');
    }

    @isTest
    static void testPreventStatusReversal_forwardTooFarBlocked() {
        // Arrange
        Job_Application__c app = [SELECT Id, Status__c FROM Job_Application__c LIMIT 1];
        app.Status__c = 'Applying';
        update app;

        // Act: Try skipping multiple statuses
        app.Status__c = 'Negotiating';
        Test.startTest();
        Database.SaveResult sr = Database.update(app, false);
        Test.stopTest();

        // Assert
        System.assertEquals(false, sr.isSuccess(), 'Should not allow skipping multiple statuses.');
    }

    @isTest
    static void testPreventStatusReversal_terminalBlocked() {
        // Arrange: step through statuses until Accepted
        Job_Application__c app = [SELECT Id, Status__c FROM Job_Application__c LIMIT 1];
        app.Status__c = 'Applying';
        update app;
        app.Status__c = 'Applied';
        update app;
        app.Status__c = 'Interviewing';
        update app;
        app.Status__c = 'Negotiating';
        update app;
        app.Status__c = 'Accepted';
        update app;

        // Act: Try to change after terminal
        app.Status__c = 'Interviewing';
        Test.startTest();
        Database.SaveResult sr = Database.update(app, false);
        Test.stopTest();

        // Assert
        System.assertEquals(false, sr.isSuccess(), 'Should not allow change from terminal status.');
        System.assert(sr.getErrors()[0].getMessage().contains('Status cannot be changed'),
            'Expected error about terminal status lock.');
    }

    // =====================================
    // AFTER UPDATE TESTS
    // =====================================

    @isTest
    static void testStatusTasks_createsTasks() {
        // Arrange: move to Applied to trigger task creation
        Job_Application__c app = [SELECT Id, Status__c FROM Job_Application__c LIMIT 1];
        app.Status__c = 'Applying';
        update app;
        app.Status__c = 'Applied';

        // Act
        Test.startTest();
        update app;
        Test.stopTest();

        // Assert
        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :app.Id];
        System.assert(tasks.size() > 0, 'At least one task should have been created from CMDT.');
    }
}
