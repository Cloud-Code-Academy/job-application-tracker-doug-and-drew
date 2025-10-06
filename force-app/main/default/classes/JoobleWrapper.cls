public with sharing class JoobleWrapper {
    public List<Job> jobs; 
    
    public class Job {
        public String title;
        public String location;
        public String snippet;
        public String salary;
        public String source;
        public String type;
        public String link;
        public String company;
        public String updated;
        public Long id;  
    }
}