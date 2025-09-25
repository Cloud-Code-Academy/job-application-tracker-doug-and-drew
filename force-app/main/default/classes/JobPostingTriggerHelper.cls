public with sharing class JobPostingTriggerHelper {
    
    
    public static void matchAndCreateAccounts( List<Job_Posting__c> newJobPostingList ) {   
        Set <String> companyNames = new Set<String>();
        for ( Job_Posting__c jp : newJobPostingList ) { 
            if ( jp.Company_Name_Text__c != null && jp.Company_Name_Text__c != ''  ) {
                // jp.Company_Name_Text__c = jp.Company_Name_Text__c.trim();
                companyNames.add(jp.Company_Name_Text__c.trim());        
            }
        }

        Map<String, Account> accMap = new Map<String, Account>();
        if ( companyNames.size() > 0 ) {
            for ( Account acc : [
                SELECT Id, Name 
                FROM Account 
                WHERE Name IN :companyNames
                ]) {
                accMap.put(acc.Name, acc);
            }
        }

        List<Job_Posting__c> newCompanies = new List<Job_Posting__c>();
        List<Job_Posting__c> postingsToUpdate = new List<Job_Posting__c>();

        for ( Job_Posting__c job : newJobPostingList) {
            String nameKey = job.Company_Name_Text__c == null ? '' : job.Company_Name_Text__c.trim();
            if(String.isBlank(nameKey)) {
                continue;
            }
            if ( accMap.containsKey(nameKey) ) {
                job.Company_Name__c = accMap.get(nameKey).Id;
                postingsToUpdate.add(job); 
            } else { 
                newCompanies.add(job); 
            } 
        }

        if (!postingsToUpdate.isEmpty()) {
            update postingsToUpdate;
        }

        List<Account> newAccounts = new List<Account>();
        
        for ( Job_Posting__c jping : newCompanies ) {
            Account newAcc = new Account();
            newAcc.Name = jping.Company_Name_Text__c.trim();
            newAccounts.add(newAcc);
            }  
            if (!newAccounts.isEmpty()) {
                insert newAccounts;   
            } 
        }
}
