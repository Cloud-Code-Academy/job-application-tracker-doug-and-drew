public with sharing class JooblePostingService {

    public static Database.UpsertResult[] normalizeDedupeAndUpsert(List<Job_Posting__c> raw) {
        if (raw == null || raw.isEmpty()) return new List<Database.UpsertResult>();

        Map<String, Job_Posting__c> byExternal = new Map<String, Job_Posting__c>();
        for (Job_Posting__c r : raw) {
            if (r == null || String.isBlank(r.JoobleId__c)) continue;
            String key = r.JoobleId__c.trim();
            if (!byExternal.containsKey(key)) {
                r.JoobleId__c = key;
                byExternal.put(key, r);
            }
        }
        if (byExternal.isEmpty()) return new List<Database.UpsertResult>();

        List<Job_Posting__c> toUpsert = new List<Job_Posting__c>(byExternal.values());
        return Database.upsert(toUpsert, Job_Posting__c.Fields.JoobleId__c, false);
    }
}