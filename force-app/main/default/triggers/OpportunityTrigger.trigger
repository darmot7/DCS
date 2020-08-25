trigger OpportunityTrigger on Opportunity (after update) {

    if(Trigger.isAfter) {
        if(Trigger.isUpdate) {
            OpportunityManager.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}