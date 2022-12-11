public with sharing class TA_Opp_CreateJournalEntriesAU implements TriggerAction.AfterUpdate {

    Map<String, String> mapStagesToStates;

    /**
     * Called from sObject Trigger Settings mdt
     */

    public void afterUpdate(
        List<Opportunity> newList, 
        List<Opportunity> oldList
    ) {
        Set<Id> setIdsWithChanges = new Set<Id>();
        Map<Id,Opportunity> oldMap = new Map<Id,Opportunity>(oldList);
        mapStagesToStates = FSL_JournalEntryService.getStageToStateMappings();

        // Add opp ids for any records with changed accounting states or amounts
        for (Opportunity opp : newList) {
            Opportunity oldOpp = oldMap.get(opp.Id);
            if (
                mapStagesToStates.get(opp.StageName) != mapStagesToStates.get(oldOpp.StageName) || 
                (mapStagesToStates.get(opp.StageName) != 'Uncommitted' && opp.Amount != oldOpp.Amount)
            ) {
                setIdsWithChanges.add(opp.Id);
            }
        }

        if (!setIdsWithChanges.isEmpty()) {
            FSL_JournalEntryService.createJournalEntries(
                setIdsWithChanges, 
                oldMap
            );
        }
    }
    
}
