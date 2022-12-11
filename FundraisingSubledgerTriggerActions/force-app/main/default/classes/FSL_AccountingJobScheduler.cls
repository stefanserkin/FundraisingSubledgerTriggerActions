/**
 * Schedule daily batch to create journal entries
 */

public with sharing class FSL_AccountingJobScheduler implements Schedulable {

    public static String schedule = '0 28 0 ? * *'; // Every day at 12:28am

    public static String run() {
        FSL_AccountingJobScheduler ajs = new FSL_AccountingJobScheduler();
        return System.schedule('Fundraising Accounting Batch', schedule, ajs);
    }

    public void execute(SchedulableContext context) {
        FSL_AccountingJobBatch ajb = new FSL_AccountingJobBatch();
        Id batchId = Database.executeBatch(ajb, 50);
    }

}
