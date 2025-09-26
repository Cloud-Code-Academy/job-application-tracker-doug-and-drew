public with sharing class JoobleCalloutInvocable {
    public class Params {
        @InvocableVariable(required=true) public String title;
        @InvocableVariable(required=true) public String location;
        @InvocableVariable public Integer radius;
        @InvocableVariable public Integer page;
        @InvocableVariable public Integer resultsPerPage;
    }
    public class Result {
        @InvocableVariable public Integer statusCode;
        // jobs parsed/returned by controller
        @InvocableVariable public Integer parsedCount;   
        @InvocableVariable public String  message;
       
    }

    @InvocableMethod(label='Fetch Jooble Jobs' description='Calls controller to fetch & upsert jobs.' callout=true)
    public static List<Result> run(List<Params> inputs) {
        List<Result> outputs = new List<Result>();
        for (Params p : inputs) {
            Result r = new Result();
            try {
                // Delegate to controller method
                List<Job_Posting__c> jobs = JoobleController.searchJobs(
                    p.title, p.location, p.radius, p.page, p.ResultsPerPage
                );

                r.statusCode  = 200;
                r.parsedCount = (jobs == null) ? 0 : jobs.size();
                r.message     = 'Success';
            } catch (Exception e) {
                // JoobleController throws AuraHandledException on non-200s; 
                r.statusCode  = null; // unknown/failed
                r.parsedCount = 0;
                r.message     = e.getMessage();
            }
            outputs.add(r);
        }
        return outputs;
    }
}