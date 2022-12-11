public with sharing class FSL_AccountingJobBatch implements Database.Batchable<sObject> {

    private static final String OPPORTUNITY_STAGE_CLOSED_WON = 'Closed Won';
    private static final String OPPORTUNITY_STAGE_PLEDGED = 'Pledged';

    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id, Amount, CloseDate, (SELECT Id, npe01__Payment_Amount__c, npe01__Payment_Method__c, npe01__Paid__c FROM npe01__OppPayment__r), (SELECT Id, npsp__Amount__c, npsp__General_Accounting_Unit__c, npsp__General_Accounting_Unit__r.Name, npsp__General_Accounting_Unit__r.GL_Code__c FROM npsp__Allocations__r) FROM Opportunity WHERE StageName = :OPPORTUNITY_STAGE_CLOSED_WON AND CloseDate = YESTERDAY';
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<Opportunity> lstOpportunities) {
        List<FSL_Journal_Entry__c> lstJEs = FSL_AccountingJobUtilities.createJournalEntries(
            lstOpportunities
        );
        if (!lstJEs.isEmpty()) {
            insert lstJEs;
        }
    }

    public void finish(Database.BatchableContext bc) {
        AsyncApexJob apexJob = [
            SELECT Id, 
                   Status, 
                   NumberOfErrors, 
                   JobItemsProcessed, 
                   TotalJobItems, 
                   CreatedBy.Email
              FROM AsyncApexJob 
             WHERE Id = :bc.getJobId()
        ];
        
        // Send email to job creator with batch results
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        String[] toAddress = new String[] {apexJob.CreatedBy.Email};
        email.setToAddresses(toAddress);
        email.setSubject(apexJob.Status + ': Fundraising Accounting Job Batch');
        email.setPlainTextBody('The FSL_AccountingJobBatch ran and processed ' + apexJob.TotalJobItems + ' batches with ' + apexJob.NumberOfErrors + ' failures. Job Id: ' + apexJob.Id);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
    }
    
}
