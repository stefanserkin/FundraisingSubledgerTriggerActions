public with sharing class TA_Opp_CreateJournalEntriesAI implements TriggerAction.AfterInsert {

    private static FSL_Fundraising_Subledger_Setting__mdt appSettings = FSL_Fundraising_Subledger_Setting__mdt.getAll().values().get(0);

    private static FSL_Accounting_Period__c openAccountingPeriod;
    private static Map<String, String> mapStagesToStates;
    private static Map<String, FSL_Global_GL_Account__mdt> mapPaymentAccounts;
    private static FSL_Global_GL_Account__mdt receivablesAccount;

    private static final String DEBIT_LABEL = 'Debit';
    private static final String CREDIT_LABEL = 'Credit';

    /**
     * Called from sObject Trigger Settings mdt (Opportunity)
     */
    
    public void afterInsert(
        List<Opportunity> newList
    ) {
        mapStagesToStates = FSL_JournalEntryService.getStageToStateMappings();
        Set<Id> setOpportunityIds = new Set<Id>();
        for (Opportunity opp : newList) {
            String strAccountingState = mapStagesToStates.get(opp.StageName);
            if (
                strAccountingState == 'Committed' || 
                (strAccountingState == 'Finalized' && opp.IsWon)
            ) {
                setOpportunityIds.add(opp.Id);
            }
        }
        createJournalEntries(setOpportunityIds);
    }

    private static void createJournalEntries(
        Set<Id> setOpportunityIds
    ) {
        List<FSL_Journal_Entry__c> lstJEs = new List<FSL_Journal_Entry__c>();

        // Set defaults
        mapPaymentAccounts = FSL_JournalEntryService.getPaymentAccountMap();
        receivablesAccount = FSL_JournalEntryService.getReceivablesAccount();
        openAccountingPeriod = FSL_JournalEntryService.getOpenAccountingPeriod();
        
        Map<Id, Opportunity> mapOpportunities = FSL_JournalEntryService.getOppsWithAccountingDetails(
            setOpportunityIds
        );

        for (Opportunity opp : mapOpportunities.values()) {
            String strAccountingState = mapStagesToStates.get(opp.StageName);
            if (strAccountingState == 'Committed') {

                // Debit receivables
                FSL_Journal_Entry__c jeDebit = new FSL_Journal_Entry__c();
                jeDebit.Date__c = Date.today();
                jeDebit.Debit__c = opp.Amount;
                jeDebit.Debit_Credit__c = DEBIT_LABEL;
                jeDebit.GL_Code__c = receivablesAccount.GL_Code__c;
                jeDebit.GL_Account_Name__c = receivablesAccount.GL_Account_Name__c;
                jeDebit.Opportunity__c = opp.Id;
                jeDebit.Account__c = opp.AccountId;
                jeDebit.Posting_Status__c = appSettings.Default_Journal_Entry_Posting_Status__c;
                jeDebit.Accounting_Period__c = openAccountingPeriod.Id;
                lstJEs.add(jeDebit);

                // Credit each allocation
                for (npsp__Allocation__c alloc : opp.npsp__Allocations__r) {
                    FSL_Journal_Entry__c jeCredit = new FSL_Journal_Entry__c();
                    jeCredit.Date__c = Date.today();
                    jeCredit.Credit__c = alloc.npsp__Amount__c;
                    jeCredit.Debit_Credit__c = CREDIT_LABEL;
                    jeCredit.GL_Code__c = alloc.npsp__General_Accounting_Unit__r.GL_Code__c;
                    jeCredit.GL_Account_Name__c = alloc.npsp__General_Accounting_Unit__r.Name;
                    jeCredit.Opportunity__c = opp.Id;
                    jeCredit.Account__c = opp.AccountId;
                    jeCredit.Allocation__c = alloc.Id;
                    jeCredit.Posting_Status__c = appSettings.Default_Journal_Entry_Posting_Status__c;
                    jeCredit.Accounting_Period__c = openAccountingPeriod.Id;
                    lstJEs.add(jeCredit);
                }

            } else if (strAccountingState == 'Finalized') {

                // Debit each payment account
                for (npe01__OppPayment__c pay : opp.npe01__OppPayment__r) {
                    FSL_Journal_Entry__c jeDebit = new FSL_Journal_Entry__c();
                    jeDebit.Date__c = Date.today();
                    jeDebit.Debit__c = pay.npe01__Payment_Amount__c;
                    jeDebit.Debit_Credit__c = DEBIT_LABEL;
                    jeDebit.GL_Code__c = pay.npe01__Payment_Method__c != null ? 
                        mapPaymentAccounts.get(pay.npe01__Payment_Method__c).GL_Code__c : 
                        appSettings.Default_Payment_GL_Code__c;
                    jeDebit.GL_Account_Name__c = pay.npe01__Payment_Method__c != null ? 
                        mapPaymentAccounts.get(pay.npe01__Payment_Method__c).GL_Account_Name__c : 
                        appSettings.Default_Payment_GL_Account_Name__c;
                    jeDebit.Opportunity__c = opp.Id;
                    jeDebit.Account__c = opp.AccountId;
                    jeDebit.Payment__c = pay.Id;
                    jeDebit.Posting_Status__c = appSettings.Default_Journal_Entry_Posting_Status__c;
                    jeDebit.Accounting_Period__c = openAccountingPeriod.Id;
                    lstJEs.add(jeDebit);
                }

                // Credit each allocation
                for (npsp__Allocation__c alloc : opp.npsp__Allocations__r) {
                    FSL_Journal_Entry__c jeCredit = new FSL_Journal_Entry__c();
                    jeCredit.Date__c = Date.today();
                    jeCredit.Credit__c = alloc.npsp__Amount__c;
                    jeCredit.Debit_Credit__c = CREDIT_LABEL;
                    jeCredit.GL_Code__c = alloc.npsp__General_Accounting_Unit__r.GL_Code__c;
                    jeCredit.GL_Account_Name__c = alloc.npsp__General_Accounting_Unit__r.Name;
                    jeCredit.Opportunity__c = opp.Id;
                    jeCredit.Account__c = opp.AccountId;
                    jeCredit.Allocation__c = alloc.Id;
                    jeCredit.Posting_Status__c = appSettings.Default_Journal_Entry_Posting_Status__c;
                    jeCredit.Accounting_Period__c = openAccountingPeriod.Id;
                    lstJEs.add(jeCredit);
                }

            }
        }

        if (!lstJEs.isEmpty()) {
            insert lstJEs;
        }

    }

}
