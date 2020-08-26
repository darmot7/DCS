@IsTest
private class OpportunityTriggerTests {
    private final static String QUALIFICATION = 'Qualification';
    private final static String NEXT_STEP = 'FAKENEXTSTEPTHISISNOTAREALVALUE';
    private final static String NEEDS_ANALYSIS = 'Needs Analysis';
    private static Date referenceDate = Date.newInstance(2020, 8, 25);
    private final static Integer numberOfOLIsPerOpp = 5;

    static List<Opportunity> createOpportunityAndRelatedOLI(Id productId, Id priceBookEntryId, Integer numberToMake) {
        List<Opportunity> oppsToInsert = new List<Opportunity>();
        for (Integer i = 0; i < numberToMake; i++) {
            Opportunity preQualificationOpportunity = new Opportunity();
            preQualificationOpportunity.Name = 'Pre-Closed Won Opportunity' + i;
            preQualificationOpportunity.CloseDate = referenceDate;
            preQualificationOpportunity.StageName = QUALIFICATION;
            preQualificationOpportunity.NextStep = NEXT_STEP;
            oppsToInsert.add(preQualificationOpportunity);
        }

        insert oppsToInsert;

        List<OpportunityLineItem> oppLineItems = new List<OpportunityLineItem>();
        for(Integer i = 0; i < numberOfOLIsPerOpp * numberToMake; i++) {
            OpportunityLineItem oli = new OpportunityLineItem();
            oli.Quantity = 11 * (i + 1);
            oli.OpportunityId = oppsToInsert[Math.mod(i, oppsToInsert.size())].Id;
            oli.UnitPrice = 44 + i;
            oli.PricebookEntryId = priceBookEntryId;
            oli.Product2Id = productId;
            oppLineItems.add(oli);
        }
        insert oppLineItems;

        return oppsToInsert;
    }

    @TestSetup
    static void setupData(){
        Product2 prod = new Product2();
        prod.Name = 'TEST PROD';
        insert prod;

        PricebookEntry pbe = new PricebookEntry();
        pbe.UnitPrice = 44;
        pbe.Pricebook2Id = Test.getStandardPricebookId();
        pbe.Product2Id = prod.Id;
        pbe.IsActive = true;
        insert pbe;

        createOpportunityAndRelatedOLI(prod.Id, pbe.Id, 1);
    }

    @IsTest
    static void handleAfterUpdate() {
        List<Opportunity> qualificationOpportunities = [
            SELECT Id, CloseDate, NextStep
            FROM Opportunity 
            WHERE StageName = :QUALIFICATION 
            AND CloseDate = :referenceDate 
            LIMIT 1];

        System.assertEquals(1, qualificationOpportunities.size());
        Opportunity qualificationOpp = qualificationOpportunities[0];

        Test.startTest();
            qualificationOpp.StageName = OpportunityManager.CLOSED_WON;
            update qualificationOpp;
        Test.stopTest();

        String opportunityFirstStage = OpportunityManager.OpportunityStageNames[0].getValue();

        List<Opportunity> renewalOpportunities = [SELECT Id,StageName,CloseDate,Type,NextStep FROM Opportunity WHERE StageName = :opportunityFirstStage AND Type = :OpportunityManager.RENEWAL LIMIT 1];
        System.assertEquals(1, renewalOpportunities.size());

        Opportunity renewalOpportunity = renewalOpportunities[0];
        System.assertEquals(opportunityFirstStage, renewalOpportunity.StageName);
        System.debug(qualificationOpp.CloseDate);
        System.assertEquals(qualificationOpp.CloseDate.addYears(1), renewalOpportunity.CloseDate);
        System.assertEquals(OpportunityManager.RENEWAL, renewalOpportunity.Type);
        System.assertEquals(qualificationOpp.NextStep, renewalOpportunity.NextStep);

        List<OpportunityLineItem> closedWonOLIs = [SELECT Id,Quantity, UnitPrice FROM OpportunityLineItem WHERE OpportunityId = :qualificationOpp.Id ORDER BY Id];
        List<OpportunityLineItem> renewalOLIs = [SELECT Id,UnitPrice,Discount,Quantity FROM OpportunityLineItem WHERE OpportunityId = :renewalOpportunity.Id ORDER BY Id];
        System.assertEquals(numberOfOLIsPerOpp, renewalOLIs.size());
        for (Integer i = 0; i < renewalOLIs.size(); i++) {
            System.assertEquals(closedWonOLIs[i].UnitPrice, renewalOLIs[i].UnitPrice);
            System.assertEquals(closedWonOLIs[i].Quantity, renewalOLIs[i].Quantity);
            System.assertEquals(0, renewalOLIs[i].Discount);
        }
    }

    @IsTest
    static void handleBulkUpdate() {
        List<Opportunity> opps = createOpportunityAndRelatedOLI([SELECT Id FROM Product2 LIMIT 1].Id, [SELECT Id FROM PricebookEntry LIMIT 1].Id, 50);
        Test.startTest();
            for (Opportunity opp : opps) {
                opp.StageName = OpportunityManager.CLOSED_WON;
            }
            update opps;
        Test.stopTest();

        System.assertEquals([SELECT Count() FROM Opportunity] * numberOfOLIsPerOpp, [SELECT Count() FROM OpportunityLineItem]);
    }

    @IsTest
    static void handleAfterUpdateNoRenewal() {
        List<Opportunity> qualificationOpportunities = [
            SELECT Id, CloseDate, NextStep
            FROM Opportunity 
            WHERE StageName = :QUALIFICATION 
            AND CloseDate = :referenceDate 
            LIMIT 1];

        System.assertEquals(1, qualificationOpportunities.size());
        Opportunity qualificationOpp = qualificationOpportunities[0];

        Test.startTest();
            qualificationOpp.StageName = NEEDS_ANALYSIS;
            update qualificationOpp;
        Test.stopTest();

        String opportunityFirstStage = OpportunityManager.OpportunityStageNames[0].getValue();
        List<Opportunity> renewalOpportunities = [SELECT Id,StageName,CloseDate,Type,NextStep FROM Opportunity WHERE StageName = :opportunityFirstStage AND Type = :OpportunityManager.RENEWAL LIMIT 1];
        System.assertEquals(0, renewalOpportunities.size());
        System.assertEquals(numberOfOLIsPerOpp, [SELECT Count() FROM OpportunityLineItem]);
    }

}
