public with sharing class Jooble2Invocable {
    public class Params {
        @InvocableVariable(required=true) public String  title;
        @InvocableVariable(required=true) public String  location;
        @InvocableVariable                public Integer radius;
        @InvocableVariable                public Integer page;
        @InvocableVariable                public Integer resultOnPage;
    }
    public class Result {
        @InvocableVariable public Integer statusCode;
        @InvocableVariable public Integer parsedCount;
        @InvocableVariable public String  message;
    }

    @InvocableMethod(label='Fetch Jooble Jobs' description='Calls controller to fetch & upsert jobs.' callout=true)
    public static List<Result> run(List<Params> inputs) {
        List<Result> outputs = new List<Result>();
        for (Params p : inputs) {
            Result r = new Result();
            try {
                List<Jooble2Parser.Job> jobsDto = Jooble2Client.getJobs(
                    p.title, p.location, p.radius, p.page, p.resultOnPage
                );
                Database.UpsertResult[] res = Jooble2Client.createJobPostings(jobsDto);

                r.statusCode  = 200;
                r.parsedCount = (jobsDto == null) ? 0 : jobsDto.size();
                r.message     = 'Upserted ' + res.size() + ' records';
            } catch (Exception e) {
                r.statusCode  = null;
                r.parsedCount = 0;
                r.message     = e.getMessage();
            }
            outputs.add(r);
        }
        return outputs;
    }
}
