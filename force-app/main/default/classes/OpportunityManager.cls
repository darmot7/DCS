public class OpportunityManager {
    @TestVisible
    private final static String CLOSED_WON = 'Closed Won';

    @TestVisible
    private final static String RENEWAL = 'Renewal';
    
    @TestVisible
    private final static List<Schema.PicklistEntry> OpportunityStageNames {
        get {
            if (OpportunityStageNames == null) {
                OpportunityStageNames = Opportunity.StageName.getDescribe().getPicklistValues();
            }
            return OpportunityStageNames;
        }
        set;
    }
    
    public static void handleAfterUpdate(List<Opportunity> updatedOpportunities, Map<Id, Opportunity> oldOpportunities) {
        Map<Id,Opportunity> opportunitiesToCreateRenewals = new Map<Id,Opportunity>();

        for(Opportunity opp : updatedOpportunities) {
            Opportunity oldOpp = oldOpportunities.get(opp.Id);
            if(opp.StageName == CLOSED_WON && opp.StageName != oldOpp.StageName) {
                opportunitiesToCreateRenewals.put(opp.Id, opp);
            }
        }

        Map<Id,Opportunity> closedOppIdToRenewalOpp = new Map<Id,Opportunity>();
        List<Opportunity> oppToInsert = new List<Opportunity>();
        List<OpportunityLineItem> relatedOpportunityLineItems = new List<OpportunityLineItem>();
        if(!opportunitiesToCreateRenewals.isEmpty()) {
            relatedOpportunityLineItems = [
                SELECT Id,OpportunityId,Quantity,UnitPrice,PricebookEntryId
                FROM OpportunityLineItem
                WHERE OpportunityId
                IN :opportunitiesToCreateRenewals.keySet()];

            for(Opportunity oppToCreateRenewalFor : opportunitiesToCreateRenewals.values()) {
                Opportunity renewalOpportunity = oppToCreateRenewalFor.clone(false,true,false,false);
                renewalOpportunity.CloseDate = oppToCreateRenewalFor.closeDate.addYears(1);
                renewalOpportunity.StageName = OpportunityStageNames[0].getValue();
                renewalOpportunity.Type = RENEWAL;
                oppToInsert.add(renewalOpportunity);
                closedOppIdToRenewalOpp.put(oppToCreateRenewalFor.Id, renewalOpportunity);
            }
        }
            
        if(!oppToInsert.isEmpty()) {
            insert oppToInsert;
            
            if(!relatedOpportunityLineItems.isEmpty()) {
                List<OpportunityLineItem> oliToInsert = new List<OpportunityLineItem>();
                for(OpportunityLineItem relatedOLI : relatedOpportunityLineItems) {
                    OpportunityLineItem newOLI = new OpportunityLineItem();
                    newOLI.Quantity = relatedOLI.Quantity;
                    newOLI.UnitPrice = relatedOLI.UnitPrice;
                    newOLI.Discount = 0;
                    newOLI.PricebookEntryId = relatedOLI.PricebookEntryId;
                    newOLI.OpportunityId = closedOppIdToRenewalOpp.get(relatedOLI.OpportunityId).Id;
                    oliToInsert.add(newOLI);
                }

                if(!oliToInsert.isEmpty()) {
                    insert oliToInsert;
                }
            }
        }
    }
}
