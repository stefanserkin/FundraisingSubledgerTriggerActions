public with sharing class FSL_JournalEntryService {

    private static FSL_Fundraising_Subledger_Setting__mdt appSettings = FSL_Fundraising_Subledger_Setting__mdt.getAll().values().get(0);

    private static FSL_Accounting_Period__c openAccountingPeriod;
    private static Map<String, String> mapStagesToStates;
    private static Map<String, FSL_Global_GL_Account__mdt> mapPaymentAccounts;
    private static FSL_Global_GL_Account__mdt receivablesAccount;

    private static final String RECEIVABLES_ACCOUNT_NAME = 'Receivables';
    private static final String DEBIT_LABEL = 'Debit';
    private static final String CREDIT_LABEL = 'Credit';
    
    /***************************
     * Main entry - record triggered events on opportunity, payment, and allocation
     *   that have accounting impact should call this method
     * @param Set<Id> Set of opportunity ids where changes occurred
     * @return FSL_Journal_Entry__c[] List of new journal entries reflecting changes
     ***************************/

    public static List<FSL_Journal_Entry__c> createJournalEntries(
        Set<Id> setOpportunityIds, 
        Map<Id, Opportunity> oldMap
    ) {
        List<FSL_Journal_Entry__c> lstJEs = new List<FSL_Journal_Entry__c>();
        List<FSL_Journal_Entry_Link__c> lstLinks = new List<FSL_Journal_Entry_Link__c>();

        Map<Id, Opportunity> mapOpportunities = getOppsWithAccountingDetails(
            setOpportunityIds
        );

        // Loop through opportunities
        // Separate into situations
        for (Opportunity opp : mapOpportunities.values()) {
            Opportunity oldOpp = oldMap.get(opp.Id);
            if (
                mapStagesToStates.get(oldOpp.StageName) == 'Uncommitted' &&
                mapStagesToStates.get(opp.StageName) == 'Finalized' && 
                opp.IsWon
            ) {

                // Debit each payment account
                for (npe01__OppPayment__c pay : opp.npe01__OppPayment__r) {
                    FSL_Journal_Entry__c jeDebit = new FSL_Journal_Entry__c();
                    jeDebit.Date__c = Date.today();
                    jeDebit.Debit__c = pay.npe01__Payment_Amount__c;
                    jeDebit.Debit_Credit__c = DEBIT_LABEL;
                    jeDebit.GL_Code__c = pay.npe01__Payment_Method__c != null ? 
                        getPaymentAccountMap().get(pay.npe01__Payment_Method__c)?.GL_Code__c : 
                        appSettings.Default_Payment_GL_Code__c;
                    jeDebit.GL_Account_Name__c = pay.npe01__Payment_Method__c != null ? 
                        getPaymentAccountMap().get(pay.npe01__Payment_Method__c)?.GL_Account_Name__c : 
                        appSettings.Default_Payment_GL_Account_Name__c;
                    jeDebit.Opportunity__c = opp.Id;
                    jeDebit.Account__c = opp.AccountId;
                    jeDebit.Payment__c = pay.Id;
                    jeDebit.Posting_Status__c = appSettings.Default_Journal_Entry_Posting_Status__c;
                    jeDebit.Accounting_Period__c = getOpenAccountingPeriod().Id;
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
                    jeCredit.Accounting_Period__c = getOpenAccountingPeriod().Id;
                    lstJEs.add(jeCredit);
                }

            } else if (
                mapStagesToStates.get(oldOpp.StageName) == 'Uncommitted' &&
                mapStagesToStates.get(opp.StageName) == 'Committed'
            ) {

                // Debit receivables
                FSL_Journal_Entry__c jeDebit = new FSL_Journal_Entry__c();
                jeDebit.Date__c = Date.today();
                jeDebit.Debit__c = opp.Amount;
                jeDebit.Debit_Credit__c = DEBIT_LABEL;
                jeDebit.GL_Code__c = getReceivablesAccount().GL_Code__c;
                jeDebit.GL_Account_Name__c = getReceivablesAccount().GL_Account_Name__c;
                jeDebit.Opportunity__c = opp.Id;
                jeDebit.Account__c = opp.AccountId;
                jeDebit.Posting_Status__c = appSettings.Default_Journal_Entry_Posting_Status__c;
                jeDebit.Accounting_Period__c = getOpenAccountingPeriod().Id;
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
                    jeCredit.Accounting_Period__c = getOpenAccountingPeriod().Id;
                    lstJEs.add(jeCredit);
                }
                
            } else if (
                mapStagesToStates.get(oldOpp.StageName) == 'Committed' && 
                mapStagesToStates.get(opp.StageName) == 'Finalized' && 
                opp.IsWon
            ) {
                Decimal paymentAmount = 0;

                // Debit each payment account
                for (npe01__OppPayment__c pay : opp.npe01__OppPayment__r) {
                    FSL_Journal_Entry__c jeDebit = new FSL_Journal_Entry__c();
                    jeDebit.Date__c = Date.today();
                    jeDebit.Debit__c = pay.npe01__Payment_Amount__c;
                    jeDebit.Debit_Credit__c = DEBIT_LABEL;
                    jeDebit.GL_Code__c = pay.npe01__Payment_Method__c != null ? 
                        getPaymentAccountMap().get(pay.npe01__Payment_Method__c)?.GL_Code__c : 
                        appSettings.Default_Payment_GL_Code__c;
                    jeDebit.GL_Account_Name__c = pay.npe01__Payment_Method__c != null ? 
                        getPaymentAccountMap().get(pay.npe01__Payment_Method__c)?.GL_Account_Name__c : 
                        appSettings.Default_Payment_GL_Account_Name__c;
                    jeDebit.Opportunity__c = opp.Id;
                    jeDebit.Account__c = opp.AccountId;
                    jeDebit.Payment__c = pay.Id;
                    jeDebit.Posting_Status__c = appSettings.Default_Journal_Entry_Posting_Status__c;
                    jeDebit.Accounting_Period__c = getOpenAccountingPeriod().Id;
                    lstJEs.add(jeDebit);
                    paymentAmount += pay.npe01__Payment_Amount__c;
                }

                // Credit receivables
                FSL_Journal_Entry__c jeCredit = new FSL_Journal_Entry__c();
                jeCredit.Date__c = Date.today();
                jeCredit.Credit__c = paymentAmount;
                jeCredit.Debit_Credit__c = CREDIT_LABEL;
                jeCredit.GL_Code__c = getReceivablesAccount().GL_Code__c;
                jeCredit.GL_Account_Name__c = getReceivablesAccount().GL_Account_Name__c;
                jeCredit.Opportunity__c = opp.Id;
                jeCredit.Account__c = opp.AccountId;
                jeCredit.Posting_Status__c = appSettings.Default_Journal_Entry_Posting_Status__c;
                jeCredit.Accounting_Period__c = getOpenAccountingPeriod().Id;
                lstJEs.add(jeCredit);
            }

        }
        if (!lstJEs.isEmpty()) {
            insert lstJEs;
        }
        return lstJEs;
    }

    /**
     * Get unique id
     */

    public static String getUUID() {
        Blob b = Crypto.GenerateAESKey(128);
        String h = EncodingUtil.ConvertTohex(b);
        String guid = h.SubString(0,8)+ '-' + h.SubString(8,12) + '-' + h.SubString(12,16) + '-' + h.SubString(16,20) + '-' + h.substring(20);
        system.debug(guid);
        return guid;
    }

    /**
     * Returns the open accounting period
     * Only one accounting period may be open at a time
     * @return FSL_Accounting_Period__c open accounting period
     */

    public static FSL_Accounting_Period__c getOpenAccountingPeriod() {
        if (openAccountingPeriod == null) {
            openAccountingPeriod = [
                SELECT Id, Start_Date__c, End_Date__c, Status__c 
                  FROM FSL_Accounting_Period__c 
                 WHERE Status__c = :appSettings.Accounting_Period_Open_Status__c 
                 LIMIT 1
            ];
        }
        return openAccountingPeriod;
    }

    /**
     * @return Map<String, String> map of opportunity stages to corresponding
     *   accounting state
     */

    public static Map<String, String> getStageToStateMappings() {
        if (mapStagesToStates == null) {
            mapStagesToStates = new Map<String, String>();
            List<FSL_Accounting_State_Mapping__mdt> lstMappings = FSL_Accounting_State_Mapping__mdt.getAll().values();
            for (FSL_Accounting_State_Mapping__mdt asm : lstMappings) {
                mapStagesToStates.put(
                    asm.Opportunity_Stage__c, 
                    asm.Accounting_State__c
                );
            }
        }
        return mapStagesToStates;
    }

    /**
     * @param set<Id> set of opportunity ids
     * @return Opportunity[] opps with payments and allocations
     */

    public static Map<Id, Opportunity> getOppsWithAccountingDetails(
        Set<Id> setOpportunityIds
    ) {
        return new Map<Id, Opportunity>([
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

    /**
     * @return Map<String, FSL_Global_GL_Account__mdt> map of payment accounts
     */

    public static Map<String, FSL_Global_GL_Account__mdt> getPaymentAccountMap() {
        if (mapPaymentAccounts == null) {
            mapPaymentAccounts = new Map<String, FSL_Global_GL_Account__mdt>();
            List<FSL_Global_GL_Account__mdt> lstAccounts = [
                SELECT Id, Label, GL_Code__c, GL_Account_Name__c 
                  FROM FSL_Global_GL_Account__mdt 
                 WHERE Payment_Account__c = true 
                 LIMIT 10000
            ];
            for (FSL_Global_GL_Account__mdt glAcc : lstAccounts) {
                mapPaymentAccounts.put(glAcc.Label, glAcc);
            }
        }
        return mapPaymentAccounts;
    }

    /**
     * @return FSL_Global_GL_Account__mdt receivable global gl account
     */

     public static FSL_Global_GL_Account__mdt getReceivablesAccount() {
        if (receivablesAccount == null) {
            receivablesAccount = FSL_Global_GL_Account__mdt.getInstance(RECEIVABLES_ACCOUNT_NAME);
        }
        return receivablesAccount;
     }

}
