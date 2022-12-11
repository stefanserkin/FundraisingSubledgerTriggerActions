public with sharing class FSL_AccountingJobUtilities {

    private static FSL_Accounting_Period__c openAccountingPeriod;

    private static final String ACCOUNTING_PERIOD_STATUS_OPEN = 'Open';
    private static final String GL_CODE_CASH = '10-10-000-10020';
    private static final String GL_NAME_CASH = 'Cash/Check';
    private static final String GL_CODE_CREDIT = '10-10-000-10023';
    private static final String GL_NAME_CREDIT = 'Credit Card';
    private static final String DEBIT_LABEL = 'Debit';
    private static final String CREDIT_LABEL = 'Credit';
    
    public static List<FSL_Journal_Entry__c> createJournalEntries(
        List<Opportunity> lstOpportunities
    ) {
        List<FSL_Journal_Entry__c> lstJEs = new List<FSL_Journal_Entry__c>();

        // TODO: Do real journal entry stuff
        // Currently returning a simple debit/credit pair for each allocation
        // assuming closed won cash payment
        for (Opportunity opp : lstOpportunities) {

            // Guard against non-payments
            if (opp.npe01__OppPayment__r.isEmpty()) {
                continue;
            }

            for (npe01__OppPayment__c pay : opp.npe01__OppPayment__r) {
                // Debit
                FSL_Journal_Entry__c jeDebit = new FSL_Journal_Entry__c();
                jeDebit.Date__c = opp.CloseDate;
                jeDebit.Debit__c = pay.npe01__Payment_Amount__c;
                jeDebit.Debit_Credit__c = DEBIT_LABEL;
                jeDebit.GL_Code__c = pay.npe01__Payment_Method__c == GL_NAME_CREDIT ? GL_CODE_CREDIT : GL_CODE_CASH;
                jeDebit.GL_Account_Name__c = pay.npe01__Payment_Method__c == GL_NAME_CREDIT ? GL_NAME_CREDIT : GL_NAME_CASH;
                jeDebit.Opportunity__c = opp.Id;
                jeDebit.Account__c = opp.AccountId;
                jeDebit.Payment__c = pay.Id;
                jeDebit.Accounting_Period__c = getOpenAccountingPeriod().Id;
                lstJEs.add(jeDebit);
            }

            for (npsp__Allocation__c alloc : opp.npsp__Allocations__r) {
                // Credit
                FSL_Journal_Entry__c jeCredit = new FSL_Journal_Entry__c();
                jeCredit.Date__c = opp.CloseDate;
                jeCredit.Credit__c = alloc.npsp__Amount__c;
                jeCredit.Debit_Credit__c = CREDIT_LABEL;
                jeCredit.GL_Code__c = alloc.npsp__General_Accounting_Unit__r.GL_Code__c;
                jeCredit.GL_Account_Name__c = alloc.npsp__General_Accounting_Unit__r.Name;
                jeCredit.Opportunity__c = opp.Id;
                jeCredit.Account__c = opp.AccountId;
                jeCredit.Allocation__c = alloc.Id;
                jeCredit.Accounting_Period__c = getOpenAccountingPeriod().Id;
                lstJEs.add(jeCredit);
            }

        }

        return lstJEs;

    }

    public static FSL_Accounting_Period__c getOpenAccountingPeriod() {
        if (openAccountingPeriod == null) {
            openAccountingPeriod = [
                SELECT Id, Start_Date__c, End_Date__c, Status__c 
                  FROM FSL_Accounting_Period__c 
                 WHERE Status__c = :ACCOUNTING_PERIOD_STATUS_OPEN 
                 LIMIT 1
            ];
        }
        return openAccountingPeriod;
    }

}
