public with sharing class Jooble2Parser {
    @AuraEnabled
    public List<Job> jobs; 

    public class Job {
        @AuraEnabled public String title;
        @AuraEnabled public String location;
        @AuraEnabled public String snippet;
        @AuraEnabled public String salary;
        @AuraEnabled public String source;
        @AuraEnabled public String type;
        @AuraEnabled public String link;
        @AuraEnabled public String company;
        @AuraEnabled public String updated;
        @AuraEnabled public Long   id;
    }

    public static List<Job> parseJobs(String jsonString) {
        Jooble2Parser wrapper = (Jooble2Parser) System.JSON.deserialize(jsonString, Jooble2Parser.class);
        return wrapper.jobs;
    }
}
