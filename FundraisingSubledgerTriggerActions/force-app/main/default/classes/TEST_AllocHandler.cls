public with sharing class TEST_AllocHandler {

    private static Map<Id, Opportunity> mapOppsCache;
    
    public static void handleInsert(List<npsp__Allocation__c> newList) {
        System.debug('::::: entered handleInsert');

        List<FSL_Journal_Entry__c> lstJEs = new List<FSL_Journal_Entry__c>();

        List<npsp__Allocation__c> lstAllocsWithDetails = getAllocations(newList);
        for (npsp__Allocation__c alloc : lstAllocsWithDetails) {
            FSL_Journal_Entry__c jeCredit = new FSL_Journal_Entry__c();
            jeCredit.Date__c = Date.today();
            jeCredit.Credit__c = alloc.npsp__Amount__c;
            jeCredit.Debit_Credit__c = 'Credit';
            jeCredit.GL_Code__c = alloc.npsp__General_Accounting_Unit__r.GL_Code__c;
            jeCredit.GL_Account_Name__c = alloc.npsp__General_Accounting_Unit__r.Name;
            jeCredit.Opportunity__c = alloc.npsp__Opportunity__c;
            jeCredit.Account__c = alloc.npsp__Opportunity__r.AccountId;
            jeCredit.Allocation__c = alloc.Id;
            jeCredit.Posting_Status__c = 'Entered';
            jeCredit.Accounting_Period__c = 'a4f7f000000DUhiAAG';
            lstJEs.add(jeCredit);
        }

        insert lstJEs;

    }

    public static void handleUpdate(
        List<npsp__Allocation__c> newList, 
        Map<Id, npsp__Allocation__c> oldMap
    ) {
        System.debug('::::: entered handleUpdate');
        List<FSL_Journal_Entry__c> lstJEs = new List<FSL_Journal_Entry__c>();

        List<npsp__Allocation__c> lstAllocsWithDetails = getAllocations(newList);
        for (npsp__Allocation__c alloc : lstAllocsWithDetails) {
            FSL_Journal_Entry__c je = new FSL_Journal_Entry__c();

            Decimal amountChanged = alloc.npsp__Amount__c - oldMap.get(alloc.Id).npsp__Amount__c;

            if (amountChanged > 0) {
                je.Date__c = Date.today();
                je.Credit__c = amountChanged;
                je.Debit_Credit__c = 'Credit';
                je.GL_Code__c = alloc.npsp__General_Accounting_Unit__r.GL_Code__c;
                je.GL_Account_Name__c = alloc.npsp__General_Accounting_Unit__r.Name;
                je.Opportunity__c = alloc.npsp__Opportunity__c;
                je.Account__c = alloc.npsp__Opportunity__r.AccountId;
                je.Allocation__c = alloc.Id;
                je.Posting_Status__c = 'Entered';
                je.Accounting_Period__c = 'a4f7f000000DUhiAAG';
                lstJEs.add(je);
            } 
            else if (amountChanged < 0) {
                je.Date__c = Date.today();
                je.Debit__c = Math.abs(amountChanged);
                je.Debit_Credit__c = 'Debit';
                je.GL_Code__c = alloc.npsp__General_Accounting_Unit__r.GL_Code__c;
                je.GL_Account_Name__c = alloc.npsp__General_Accounting_Unit__r.Name;
                je.Opportunity__c = alloc.npsp__Opportunity__c;
                je.Account__c = alloc.npsp__Opportunity__r.AccountId;
                je.Allocation__c = alloc.Id;
                je.Posting_Status__c = 'Entered';
                je.Accounting_Period__c = 'a4f7f000000DUhiAAG';
                lstJEs.add(je);
            }

        }

        insert lstJEs;
    }

    public static void handleDelete(List<npsp__Allocation__c> oldList) {
        System.debug('::::: entered handleDelete with ' + oldList.size() + ' jes');

        List<FSL_Journal_Entry__c> lstJEs = new List<FSL_Journal_Entry__c>();

        List<npsp__Allocation__c> lstAllocsWithDetails = [
            SELECT Id, 
                   npsp__Amount__c, 
                   npsp__Opportunity__c, 
                   npsp__Opportunity__r.AccountId, 
                   npsp__General_Accounting_Unit__c, 
                   npsp__General_Accounting_Unit__r.Name, 
                   npsp__General_Accounting_Unit__r.GL_Code__c 
              FROM npsp__Allocation__c
             WHERE Id IN :oldList
                   ALL ROWS
        ];
        System.debug('::::: received ' + lstAllocsWithDetails.size() + ' jes from query');

        for (npsp__Allocation__c alloc : lstAllocsWithDetails) {
            FSL_Journal_Entry__c je = new FSL_Journal_Entry__c();
            je.Date__c = Date.today();
            je.Debit__c = alloc.npsp__Amount__c;
            je.Debit_Credit__c = 'Debit';
            je.GL_Code__c = alloc.npsp__General_Accounting_Unit__r.GL_Code__c;
            je.GL_Account_Name__c = alloc.npsp__General_Accounting_Unit__r.Name;
            je.Opportunity__c = alloc.npsp__Opportunity__c;
            je.Account__c = alloc.npsp__Opportunity__r.AccountId;
            je.Posting_Status__c = 'Entered';
            je.Accounting_Period__c = 'a4f7f000000DUhiAAG';
            lstJEs.add(je);
        }

        insert lstJEs;
    }

    public static Map<Id, Opportunity> getOppsWithAccountingDetails(
        Set<Id> setOpportunityIds
    ) {
        if (mapOppsCache == null) {
            mapOppsCache = new Map<Id, Opportunity>([
                SELECT Id, Amount, CloseDate, StageName, AccountId, IsWon, 
                       (SELECT Id, npe01__Payment_Amount__c, npe01__Payment_Method__c, npe01__Paid__c 
                          FROM npe01__OppPayment__r), 
                       (SELECT Id, npsp__Amount__c, npsp__General_Accounting_Unit__c, npsp__General_Accounting_Unit__r.Name, npsp__General_Accounting_Unit__r.GL_Code__c 
                          FROM npsp__Allocations__r), 
                       (SELECT Id, Debit__c, Credit__c, GL_Code__c 
                          FROM Journal_Entries__r)
                  FROM Opportunity
                 WHERE Id IN :setOpportunityIds
                 LIMIT 10000
            ]);
        }
        return mapOppsCache;
    }

    private static List<npsp__Allocation__c> getAllocations(
        List<npsp__Allocation__c> newList
    ) {
        return [
            SELECT Id, 
                   npsp__Amount__c, 
                   npsp__Opportunity__c, 
                   npsp__Opportunity__r.AccountId, 
                   npsp__General_Accounting_Unit__c, 
                   npsp__General_Accounting_Unit__r.Name, 
                   npsp__General_Accounting_Unit__r.GL_Code__c 
              FROM npsp__Allocation__c
             WHERE Id IN :newList
        ];
    }

}
