@IsTest
public class JoobleControllerTest {

    
    private class Mock200Insert implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            JoobleWrapper w = new JoobleWrapper();
            w.jobs = new List<JoobleWrapper.Job>();

            JoobleWrapper.Job j = new JoobleWrapper.Job();
            j.id       = 229466029179676204L; // unique Long
            j.title    = 'Salesforce Developer';
            j.company  = 'Acme Corp';
            j.location = 'Denver, CO';
            j.link     = 'https://example.com/job/229466029179676204';
            j.snippet  = 'Great <b>Apex/LWC</b> role.';
            j.salary   = '$120k';
            j.updated  = '2025-09-26T00:00:00.0000000';
            w.jobs.add(j);

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(w));
            return res;
        }
    }

    
    private class Mock200Update implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            JoobleWrapper w = new JoobleWrapper();
            w.jobs = new List<JoobleWrapper.Job>();

            JoobleWrapper.Job j = new JoobleWrapper.Job();
            j.id       = 999999999999999999L; 
            j.title    = 'Updated Title';     // prove update happens
            j.company  = 'OldCo';             
            j.location = 'Denver, CO';
            j.link     = 'https://example.com/job/seed';
            j.snippet  = 'Updated snippet';
            j.salary   = '$130k';
            j.updated  = '2025-09-26T00:00:00.0000000';
            w.jobs.add(j);

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(w));
            return res;
        }
    }

    // ---- Mock: 500 error ----
    private class Mock500 implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"error":"Internal"}');
            return res;
        }
    }

    // Seed a record for the UPDATE/DEDUPE test in its own transaction
    @testSetup
    static void seedExistingPosting() {
        insert new Job_Posting__c(
            JoobleId__c          = '999999999999999999',
            Title_Position__c    = 'Old Title',
            Company_Name_Text__c = 'OldCo',
            Posting_URL__c       = 'https://example.com/job/seed',
            Location__c          = 'Denver, CO'
            // If your Job_Posting__c uses a Text Name field (not Auto Number),
            // add: Name = 'Seeded'
        );
    }

    @IsTest
    static void test_InsertsNew() {
        Test.setMock(HttpCalloutMock.class, new Mock200Insert());

        Test.startTest();
        List<Job_Posting__c> out = JoobleController.searchJobs('Salesforce Developer','Denver, CO',25,1,10);
        Test.stopTest();

        System.assertEquals(1, out.size(), 'Should parse one job');

        List<Job_Posting__c> rows = [
            SELECT Id, JoobleId__c, Title_Position__c, Posting_URL__c
            FROM Job_Posting__c
            WHERE JoobleId__c = '229466029179676204'
        ];
        System.assertEquals(1, rows.size(), 'One row should be inserted');
        System.assertEquals('Salesforce Developer', rows[0].Title_Position__c);
    }

    @IsTest
    static void test_UpdatesExisting_Dedupe() {
        // No DML here before the callout; the record already exists via @testSetup
        Test.setMock(HttpCalloutMock.class, new Mock200Update());

        Test.startTest();
        List<Job_Posting__c> out = JoobleController.searchJobs('Salesforce Developer','Denver, CO',25,1,10);
        Test.stopTest();

        Integer cnt = [SELECT COUNT() FROM Job_Posting__c WHERE JoobleId__c = '999999999999999999'];
        System.assertEquals(1, cnt, 'Upsert should dedupe on JoobleId__c (no duplicates)');

        Job_Posting__c rec = [
            SELECT Title_Position__c, Company_Name_Text__c, Posting_URL__c
            FROM Job_Posting__c
            WHERE JoobleId__c = '999999999999999999'
            LIMIT 1
        ];
        System.assertEquals('Updated Title', rec.Title_Position__c, 'Existing record should be updated');
    }

//     @IsTest
// static void test_ErrorPath() {
    
//     Test.setMock(HttpCalloutMock.class, new HttpCalloutMock() {
//         public HttpResponse respond(HttpRequest req) {
//             HttpResponse res = new HttpResponse();
//             res.setStatusCode(500);
//             res.setBody(''); 
//             return res;
//         }
//     });

//     try {
//         Test.startTest();
//         JoobleController.searchJobs('x','y',null,null,null);
//         Test.stopTest();
//         System.assert(false, 'Expected AuraHandledException on non-200');
//     } catch (AuraHandledException e) {
//         System.assert(e.getMessage().contains('Jooble Error 500'),
//             'Message should include status 500');
//     }
// }

}
