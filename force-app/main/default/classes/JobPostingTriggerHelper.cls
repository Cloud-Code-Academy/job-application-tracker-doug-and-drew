public inherited sharing class JobPostingTriggerHelper {    
    
    private static String keyOf(String s) {
        return String.isBlank(s) ? null : s.trim().toLowerCase();
    }

    public static void matchAndCreateAccounts(List<Job_Posting__c> newJobPostingList) {

    System.debug(LoggingLevel.WARN, 'ENTER matchAndCreateAccounts, inputs=' + newJobPostingList.size());

    // 1) Collect distinct raw names for the SOQL IN clause
    Set<String> rawNames = new Set<String>();
    for (Job_Posting__c jp : newJobPostingList) {
        if (!String.isBlank(jp.Company_Name_Text__c)) {
            rawNames.add(jp.Company_Name_Text__c.trim());
        }
    }

    // 2) Query existing accounts, map by normalized key
    Map<String, Account> accMap = new Map<String, Account>();
    if (!rawNames.isEmpty()) {
        for (Account a : [SELECT Id, Name FROM Account WHERE Name IN :rawNames WITH USER_MODE]) {
            accMap.put(keyOf(a.Name), a);
        }
    }

    // 3) Phase 1: postings that match existing accounts vs those needing new accounts
    List<Job_Posting__c> toUpdateExisting = new List<Job_Posting__c>();
    List<Job_Posting__c> needsNewAccount  = new List<Job_Posting__c>();

    for (Job_Posting__c jp : newJobPostingList) {
        String k = keyOf(jp.Company_Name_Text__c);
        if (k == null) { continue; }

        Account a = accMap.get(k);
        if (a != null) {
            jp.Company_Name__c = a.Id;
        
        } else {
            needsNewAccount.add(jp);
        }
    }

    // 4) Create accounts when they are missing 
    Set<String> toCreateKeys = new Set<String>();
    List<Account> newAccounts = new List<Account>();
    for (Job_Posting__c jp : needsNewAccount) {
        String k = keyOf(jp.Company_Name_Text__c);
        if (k == null || toCreateKeys.contains(k)) {continue;}
        newAccounts.add(new Account(Name = jp.Company_Name_Text__c.trim()));
        toCreateKeys.add(k);
    }

    Map<String, Id> newAccIdsByKey = new Map<String, Id>();
    if (!newAccounts.isEmpty()) {
    Database.SaveResult[] ins = Database.insert(newAccounts, /*allOrNone*/ false);
    for (Integer i = 0; i < ins.size(); i++) {
        if (!ins[i].isSuccess()) {
            System.debug(LoggingLevel.ERROR, 'Insert failed[' + i + ']: ' + ins[i].getErrors()[0].getMessage());
        } else {
            // map by normalized name → Id
            String k = keyOf(newAccounts[i].Name);
            if (k != null) { 
                newAccIdsByKey.put(k, ins[i].getId()); 
            }
        }
    }
}   

    // 5) Phase 2: link postings that needed new accounts
    List<Job_Posting__c> toUpdateNewlyCreated = new List<Job_Posting__c>();
    for (Job_Posting__c jp : needsNewAccount) {
        String k = keyOf(jp.Company_Name_Text__c);
        if (k != null && newAccIdsByKey.containsKey(k)) {
            jp.Company_Name__c = newAccIdsByKey.get(k);
        }
    } 
    
}

}