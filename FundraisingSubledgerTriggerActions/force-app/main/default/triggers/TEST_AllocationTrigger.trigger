trigger TEST_AllocationTrigger on npsp__Allocation__c (
    after insert, after update, after delete
) {

    if (Trigger.isInsert) {
        TEST_AllocHandler.handleInsert(Trigger.new);
    }

    if (Trigger.isUpdate) {
        TEST_AllocHandler.handleUpdate(Trigger.new, Trigger.oldMap);
    }

    if (Trigger.isDelete) {
        TEST_AllocHandler.handleDelete(Trigger.old);
    }

}