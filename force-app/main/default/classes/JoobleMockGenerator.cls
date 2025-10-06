@isTest
public with sharing class JoobleMockGenerator implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
        JoobleWrapper wrapper = new JoobleWrapper();
        wrapper.jobs = new List<JoobleWrapper.Job>();

        JoobleWrapper.Job j = new JoobleWrapper.Job();
        j.id = 99057693440045656L;           
        j.title = 'Salesforce Developer';
        j.company = 'Acme Corp';
        j.location = 'Denver, CO';
        j.link = 'https://example.com/job/JBL-0001';
        j.snippet = 'Great role working on Apex/LWC.';
        j.updated = String.valueOf(Date.today());     
        wrapper.jobs.add(j);

        String jsonPayload = JSON.serialize(wrapper);
        HttpResponse res = new HttpResponse();
        req.setHeader('Content-Type', 'application/json');
        res.setBody(jsonPayload);
        res.setStatusCode(200);
        return res;
    }

}