@IsTest
private class Jooble2ClientTest {

    // --- Request capture for assertions
    @TestVisible
    private static HttpRequest LAST_REQ;

    // --- Mocks --------------------------------------------------------------

    // Returns a parametrized response and captures the outbound request.
    private class SimpleHttpMock implements HttpCalloutMock {
        Integer code; String status; String body; Map<String,String> headers;
        SimpleHttpMock(Integer c, String s, String b, Map<String,String> h){
            code=c; status=s; body=b; headers = (h==null? new Map<String,String>() : h);
        }
        public HttpResponse respond(HttpRequest req){
            Jooble2ClientTest.LAST_REQ = req;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(code); res.setStatus(status); res.setBody(body);
            for(String k: headers.keySet()) res.setHeader(k, headers.get(k));
            return res;
        }
    }

    // Throws to simulate transport errors (to drive invocable's catch block).
    private class ThrowingHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req){
            throw new CalloutException('Simulated transport failure');
        }
    }

    // --- Fixture ------------------------------------------------------------

    // Matches your Jooble2Parser: top-level "jobs" with fields in your wrapper.
    private static String mockSuccessBody(){
        return JSON.serialize(new Map<String,Object>{
            'jobs' => new List<Object>{
                new Map<String,Object>{
                    'id'       => 101,
                    'title'    => 'Salesforce Developer',
                    'company'  => 'Acme Corp',
                    'location' => 'Atlanta, GA',
                    'salary'   => '$100k-$120k',
                    'link'     => 'https://example.com/jobs/101',
                    'snippet'  => '<p>Build stuff &amp; fix bugs&nbsp;</p>',
                    'updated'  => '2025-09-30T10:20:30Z',
                    'source'   => 'Jooble',
                    'type'     => 'Full-time'
                },
                new Map<String,Object>{
                    'id'       => 102,
                    'title'    => 'Sr Salesforce Admin',
                    'company'  => 'Globex',
                    'location' => 'Atlanta, GA',
                    'salary'   => '$120k-$135k',
                    'link'     => 'https://example.com/jobs/102',
                    'snippet'  => null, // exercises cleanSnippet null path
                    'updated'  => 'not-a-date', // exercises tryParseIsoDate failure
                    'source'   => 'Jooble',
                    'type'     => 'Full-time'
                }
            }
        });
    }

    // --- Client tests -------------------------------------------------------

        @IsTest
    static void test_getJobs_success_and_createUpserts() {
        // Arrange
        Test.setMock(
            HttpCalloutMock.class,
            new SimpleHttpMock(200, 'OK', mockSuccessBody(), new Map<String,String>{ 'Content-Type' => 'application/json' })
        );

        List<Jooble2Parser.Job> jobs;
        Database.UpsertResult[] upserts1;
        Database.UpsertResult[] upserts2;

        Test.startTest();
        // Act (all calls inside one start/stop block)
        jobs = Jooble2Client.getJobs('Salesforce', 'Atlanta, GA', 25, 1, 5);
        upserts1 = Jooble2Client.createJobPostings(jobs);        // first upsert
        upserts2 = Jooble2Client.createJobPostings(jobs);        // idempotency re-upsert
        Test.stopTest();

        // Assert request config & payload
        System.assertNotEquals(null, LAST_REQ, 'Expected an HTTP request');
        System.assertEquals('POST', LAST_REQ.getMethod());
        System.assertEquals('callout:Jooble2', LAST_REQ.getEndpoint());
        System.assertEquals('application/json', LAST_REQ.getHeader('Content-Type'));

        Map<String,Object> sent = (Map<String,Object>) JSON.deserializeUntyped(LAST_REQ.getBody());
        System.assertEquals('Salesforce', (String)sent.get('keywords'));
        System.assertEquals('Atlanta, GA', (String)sent.get('location'));
        System.assertEquals(25, (Integer)sent.get('radius'));
        System.assertEquals(1, (Integer)sent.get('page'));
        System.assertEquals(5, (Integer)sent.get('ResultOnPage'));

        // Assert parsed jobs and upserts
        System.assertEquals(2, jobs.size(), 'Parser should return two jobs from mock');
        System.assertEquals(2, upserts1.size());
        for (Database.UpsertResult r : upserts1) System.assert(r.isSuccess());
        System.assertEquals(2, upserts2.size());

        // Verify mapped fields for job 101
        Job_Posting__c jp101 = [
            SELECT Title_Position__c, Company_Name_Text__c, Location__c, Salary__c,
                Posting_URL__c, Job_Description__c, Updated__c
            FROM Job_Posting__c
            WHERE JoobleId__c = '101' LIMIT 1
        ];
        System.assertEquals('Salesforce Developer', jp101.Title_Position__c);
        System.assertEquals('Acme Corp', jp101.Company_Name_Text__c);
        System.assertEquals('Atlanta, GA', jp101.Location__c);
        System.assertEquals('$100k-$120k', jp101.Salary__c);
        System.assertEquals('https://example.com/jobs/101', jp101.Posting_URL__c);
        System.assertEquals('Build stuff & fix bugs', jp101.Job_Description__c);
        System.assertEquals(Date.newInstance(2025, 9, 30), jp101.Updated__c);

        // Verify edge cases for job 102
        Job_Posting__c jp102 = [
            SELECT Job_Description__c, Updated__c
            FROM Job_Posting__c
            WHERE JoobleId__c = '102' LIMIT 1
        ];
        System.assertEquals(null, jp102.Job_Description__c);
        System.assertEquals(null, jp102.Updated__c);

        // Idempotency: still exactly two rows
        Integer ct = [SELECT COUNT() FROM Job_Posting__c WHERE JoobleId__c IN ('101','102')];
        System.assertEquals(2, ct, 'External ID upsert should prevent duplicates');
    }


    @IsTest
    static void test_getJobs_non200_returnsEmpty() {
        Test.setMock(
            HttpCalloutMock.class,
            new SimpleHttpMock(500, 'Internal Server Error', '{"error":"boom"}', null)
        );

        Test.startTest();
        List<Jooble2Parser.Job> jobs = Jooble2Client.getJobs('Admin', 'Denver, CO', 10, 1, 5);
        Test.stopTest();

        System.assertEquals(0, jobs.size(), 'Non-200 should return empty list');
    }

    @IsTest
    static void test_createJobPostings_null_and_empty_inputs() {
        Database.UpsertResult[] a = Jooble2Client.createJobPostings(null);
        System.assertEquals(0, a.size());

        Database.UpsertResult[] b = Jooble2Client.createJobPostings(new List<Jooble2Parser.Job>());
        System.assertEquals(0, b.size());
    }

    // --- Invocable tests ----------------------------------------------------

    @IsTest
    static void test_invocable_success() {
        // Mock the callout for the internal getJobs() used by the invocable
        Test.setMock(
            HttpCalloutMock.class,
            new SimpleHttpMock(200, 'OK', mockSuccessBody(), new Map<String,String>{ 'Content-Type' => 'application/json' })
        );

        // Build inputs
        Jooble2Invocable.Params p = new Jooble2Invocable.Params();
        p.title = 'Salesforce';
        p.location = 'Atlanta, GA';
        p.radius = 25;
        p.page = 1;
        p.resultOnPage = 5;

        Test.startTest();
        List<Jooble2Invocable.Result> out = Jooble2Invocable.run(new List<Jooble2Invocable.Params>{ p });
        Test.stopTest();

        System.assertEquals(1, out.size(), 'One result expected');
        System.assertEquals(200, out[0].statusCode, 'Success path sets 200');
        System.assertEquals(2, out[0].parsedCount, 'Should reflect parsed job count');
        System.assert(out[0].message != null && out[0].message.contains('Upserted 2'), 'Message should mention two upserts');

        // Sanity: records exist
        Integer ct = [SELECT COUNT() FROM Job_Posting__c WHERE JoobleId__c IN ('101','102')];
        System.assertEquals(2, ct);
    }

    @IsTest
    static void test_invocable_error_path_sets_null_statusCode() {
        // Make the inner client call throw so we hit the catch block
        Test.setMock(HttpCalloutMock.class, new ThrowingHttpMock());

        Jooble2Invocable.Params p = new Jooble2Invocable.Params();
        p.title = 'Anything';
        p.location = 'Anywhere';
        p.radius = 10;
        p.page = 1;
        p.resultOnPage = 5;

        Test.startTest();
        List<Jooble2Invocable.Result> out = Jooble2Invocable.run(new List<Jooble2Invocable.Params>{ p });
        Test.stopTest();

        System.assertEquals(1, out.size());
        System.assertEquals(null, out[0].statusCode, 'On exception, statusCode should be null per your code');
        System.assertEquals(0, out[0].parsedCount, 'On exception, parsedCount = 0');
        System.assert(out[0].message != null && out[0].message.contains('Simulated transport failure'),
            'Catch should surface exception message');
    }
}
