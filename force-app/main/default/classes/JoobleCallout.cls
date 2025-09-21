public with sharing class JoobleCallout {
       

        public static HttpResponse search(String title, String location, Integer radius, Integer page, Integer resultsPerPage) {
        
        HttpRequest req = new HttpRequest();
        req.setEndPoint('callout:JoobleAPI'); //callout:JoobleAPI/
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');

        Map<String, Object> body = new Map<String, Object>{
            'keywords' => title,
            'location' => location,
            'radius' => radius,
            'page' => page,
            'ResultOnPage' => resultsPerPage
        };
        
        req.setBody(JSON.serialize(body));
        
        Http http = new Http();
        HttpResponse res = http.send(req);

        System.debug('Status: ' + res.getStatus() + ' (' + res.getStatusCode() + ')');
		System.debug('Response Body: ' + res.getBody());

        if ( res.getStatusCode() == 200) {
            String responseBody = res.getBody();
            List<Job_Posting__c> jobs = createJobsFromJson(responseBody);
            if (!jobs.isEmpty()) {
                Database.upsert(jobs, Job_Posting__c.Fields.JoobleId__c, false);
                System.debug('Upserted ' + jobs.size() + ' job(s). First record (pre-ID): ' + jobs[0]);
            } else {
                System.debug('No jobs found in payload.');
            }
        } 
        return res;
    }
            

        @TestVisible
public static List<Job_Posting__c> createJobsFromJson(String jsonString) {
    JoobleWrapper jw = (JoobleWrapper) JSON.deserialize(jsonString, JoobleWrapper.class);

    List<Job_Posting__c> out = new List<Job_Posting__c>();
    if (jw == null || jw.jobs == null || jw.jobs.isEmpty()) return out;

    for (JoobleWrapper.Job src : jw.jobs) {
        if (src == null) continue;
        Job_Posting__c rec = new Job_Posting__c();

        // If you keep Long in the wrapper:
        rec.JoobleId__c        = (src.id == null) ? null : String.valueOf(src.id);
        // If you switch to String in the wrapper instead:
        // rec.JoobleId__c     = String.isBlank(src.id) ? null : src.id.trim();

        rec.Title_Position__c  = src.title;
        rec.Company_Name__c    = src.company;
        rec.Location__c        = src.location;
        rec.Job_Description__c = cleanSnippet(src.snippet);
        rec.Salary__c          = src.salary;
        rec.Posting_URL__c     = src.link;

        Date d = tryParseIsoDate(src.updated);
        if (d != null) rec.Updated__c = d;

        out.add(rec);
    }
    return out;
}

private static Date tryParseIsoDate(String iso) {
    if (String.isBlank(iso) || iso.length() < 10) return null;
    try { return Date.valueOf(iso.substring(0, 10)); } // "YYYY-MM-DD"
    catch (Exception e) { System.debug(LoggingLevel.WARN, 'ISO date parse failed: ' + iso); return null; }
}

private static String cleanSnippet(String raw) {
    if (String.isBlank(raw)) return null;
    String s = raw.replaceAll('<[^>]*>', '');
    s = s.replace('&nbsp;', ' ').replace('&amp;', '&').replace('&lt;', '<').replace('&gt;', '>');
    return s.trim();
}

    
}