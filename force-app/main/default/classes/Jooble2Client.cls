public with sharing class Jooble2Client {
//    private static final String JOOBLE_URL = 'https://jooble.org/api/ff067e2c-d3b7-42fa-bac5-0be71b542fab';
   private static final String POST = 'POST';

   public static List<Jooble2Parser.Job> getJobs(String title, String location, Integer radius, Integer page, Integer resultOnPage) {
    List<Jooble2Parser.Job> jobPosts = new List<Jooble2Parser.Job>();
    
    Http httpCallout = new Http();
    HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:Jooble2');
    req.setMethod(POST);
    req.setHeader('Content-Type', 'application/json');
    req.setTimeout(20000);

    Map<String, Object> body = new Map<String, Object>{
            'keywords' => title,
            'location' => location,
            'radius' => radius,
            'page' => page,
            'ResultOnPage' => resultOnPage
        };
        req.setBody(JSON.serialize(body));

    HttpResponse res = httpCallout.send(req);

    if (res.getStatusCode() != 200) {
        System.debug(LoggingLevel.ERROR, 'Jooble error: ' + res.getStatus() + ' ' + res.getBody());
        return new List<Jooble2Parser.Job>();
    }

    List<Jooble2Parser.Job> jobs = Jooble2Parser.parseJobs(res.getBody());
//    List<Jooble2Parser.Job> jobs = Jooble2Parser.Job;
    

    for(Jooble2Parser.Job job : jobs) {
        jobPosts.add(job);
    }

    for (Jooble2Parser.Job j : jobs) {
            System.debug(j.title + ' | ' + j.location + ' | ' + j.salary);
        }

    return jobPosts;
   }

    public static Database.UpsertResult[] createJobPostings(List<Jooble2Parser.Job> dtos) {
        if (dtos == null || dtos.isEmpty()) return new Database.UpsertResult[0];

        List<Job_Posting__c> posts = new List<Job_Posting__c>();
        for (Jooble2Parser.Job j : dtos) {
            Job_Posting__c rec = new Job_Posting__c();
                rec.JoobleId__c          = String.valueOf(j.id);  
                rec.Title_Position__c    = j.title;
                rec.Company_Name_Text__c = j.company;
                rec.Location__c          = j.location;
                rec.Salary__c            = j.salary;
                rec.Posting_URL__c       = j.link;
                rec.Job_Description__c   = cleanSnippet(j.snippet);

                Date d = tryParseIsoDate(j.updated);
                if (d != null) {rec.Updated__c = d;} 

                posts.add(rec);
        }
          
        return Database.upsert(posts, Job_Posting__c.Fields.JoobleId__c, /*allOrNone*/ false);
    }

    private static Date tryParseIsoDate(String iso) {
        if (String.isBlank(iso) || iso.length() < 10) {return null;}
        try { return Date.valueOf(iso.substring(0, 10)); }
        catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'ISO date parse failed: ' + iso);
            return null;
        }
    }

    private static String cleanSnippet(String raw) {
        if (String.isBlank(raw)) {return null;}
        String s = raw.replaceAll('<[^>]*>', '');
        s = s.replace('&nbsp;', ' ').replace('&amp;', '&').replace('&lt;', '<').replace('&gt;', '>');
        return s.trim();
    }
}