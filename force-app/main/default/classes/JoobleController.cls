public with sharing class JoobleController {
    @AuraEnabled(cacheable=false)
    public static List<Job_Posting__c> searchJobs (
        String title, 
        String location, 
        Integer radius, 
        Integer page, 
        Integer resultsPerPage
    ) {
        HttpResponse res = JoobleCallout.search(title, location, radius, page, resultsPerPage);

        if ( res.getStatusCode() == 200) {
            List<Job_Posting__c> jobs = JoobleCallout.createJobsFromJson(res.getBody());
            JoobleCallout.upsertJobs(jobs);
            return jobs;
        } else {
            throw new AuraHandledException(
                'Jooble Error: ' + res.getStatusCode() + 
                ': ' + res.getStatusCode());
        }
    }
}