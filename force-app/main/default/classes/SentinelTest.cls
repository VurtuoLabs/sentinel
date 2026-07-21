@isTest
private class SentinelTest {

    /** Opportunity whose CreatedDate is backdated so staleness queries match it. */
    private static Opportunity staleOpp() {
        Opportunity o = new Opportunity(
            Name = 'Sentinel Stale Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 5000
        );
        insert o;
        Test.setCreatedDate(o.Id, Datetime.now().addDays(-400));
        return o;
    }

    /** In-memory config pointing at Opportunity via CreatedDate (backdatable in tests). */
    private static Sentinel_Config__mdt oppConfig() {
        return new Sentinel_Config__mdt(
            Object_API_Name__c = 'Opportunity',
            Date_Field__c = 'CreatedDate',
            Stale_Days__c = 30,
            Owner_Field__c = 'OwnerId',
            Priority_Field__c = 'StageName',
            Name_Field__c = 'Name',
            Filter_Criteria__c = 'IsClosed = false',
            Sort_Field__c = 'Amount',
            Sort_Direction__c = 'DESC',
            Threshold_Alert__c = 1,
            Is_Active__c = true,
            Label__c = 'Test Pipeline'
        );
    }

    @isTest
    static void runCheckBuildsEnrichedRecords() {
        staleOpp();
        Test.startTest();
        SentinelService.Report rep = SentinelService.runCheck(oppConfig(), 'all');
        Test.stopTest();

        System.assert(rep.staleCount >= 1, 'Backdated opp should be at-risk');
        SentinelService.RecordInfo ri = rep.records[0];
        System.assertEquals('Critical', ri.band, '400 days vs 30-day threshold is Critical');
        System.assert(ri.url.contains('/lightning/r/'), 'Record should have a deep link');
        System.assertNotEquals(null, ri.ownerName, 'OwnerId should resolve Owner.Name');
        System.assert(!rep.summary.byBand.isEmpty(), 'Summary bands should be populated');
        System.assertEquals('Test Pipeline', rep.label);
    }

    @isTest
    static void ownerScopeMineFilters() {
        staleOpp();
        Test.startTest();
        SentinelService.Report mine = SentinelService.runCheck(oppConfig(), 'mine');
        Test.stopTest();
        // Current user owns the inserted opp, so 'mine' still returns it.
        System.assert(mine.staleCount >= 1, 'Running user owns the record');
    }

    @isTest
    static void unsafeIdentifierThrows() {
        Sentinel_Config__mdt bad = oppConfig();
        bad.Name_Field__c = 'Name; DROP';
        Boolean threw = false;
        try {
            SentinelService.runCheck(bad, 'all');
        } catch (SentinelService.SentinelException e) {
            threw = true;
        }
        System.assert(threw, 'Unsafe identifier must raise SentinelException');
    }

    @isTest
    static void healthCheckInvocable() {
        SentinelHealthCheck.Request req = new SentinelHealthCheck.Request();
        req.objectApiName = 'Opportunity';
        Test.startTest();
        List<SentinelHealthCheck.Result> res = SentinelHealthCheck.check(
            new List<SentinelHealthCheck.Request>{ req });
        Test.stopTest();
        System.assertEquals(1, res.size());
        System.assertNotEquals(null, res[0].staleRecordsJson);
        System.assertNotEquals(null, res[0].summaryJson);
        System.assertNotEquals(null, res[0].label);
    }

    @isTest
    static void rollupInvocable() {
        SentinelRollupAction.Request req = new SentinelRollupAction.Request();
        req.ownerScope = 'all';
        Test.startTest();
        List<SentinelRollupAction.Result> res = SentinelRollupAction.check(
            new List<SentinelRollupAction.Request>{ req });
        Test.stopTest();
        System.assertEquals(1, res.size());
        System.assert(res[0].objectCount >= 1, 'At least one active config expected');
        System.assertNotEquals(null, res[0].rollupJson);
    }

    @isTest
    static void reassignAction() {
        Opportunity o = staleOpp();
        SentinelReassignAction.Request req = new SentinelReassignAction.Request();
        req.recordIds = o.Id;
        Test.startTest();
        List<SentinelReassignAction.Result> res = SentinelReassignAction.reassign(
            new List<SentinelReassignAction.Request>{ req });
        Test.stopTest();
        System.assertEquals(1, res[0].updatedCount);
    }

    @isTest
    static void followUpAction() {
        Opportunity o = staleOpp();
        Lead l = new Lead(LastName = 'Sentinel', Company = 'Acme', Status = 'Open - Not Contacted');
        insert l;

        SentinelFollowUpAction.Request req = new SentinelFollowUpAction.Request();
        req.recordIds = o.Id + ',' + l.Id;
        req.subject = 'Check in';
        req.dueInDays = '5';
        Test.startTest();
        List<SentinelFollowUpAction.Result> res = SentinelFollowUpAction.followUp(
            new List<SentinelFollowUpAction.Request>{ req });
        Test.stopTest();
        System.assertEquals(2, res[0].createdCount);
        System.assertEquals(2, [SELECT COUNT() FROM Task WHERE Subject = 'Check in']);
    }

    @isTest
    static void dashboardController() {
        Test.startTest();
        SentinelDashboardController.Overview ov =
            SentinelDashboardController.getOverview('all');
        Test.stopTest();
        System.assertNotEquals(null, ov);
        System.assert(ov.objectCount >= 1);
        System.assertNotEquals(null, ov.objects);
    }

    @isTest
    static void monitorRuns() {
        staleOpp();
        Test.startTest();
        Integer total = SentinelMonitor.run();
        SentinelMonitor m = new SentinelMonitor();
        m.execute(null);
        Test.stopTest();
        System.assert(total >= 0, 'Monitor returns a non-negative total');
    }

    @isTest
    static void monitorFiresThresholdAlert() {
        // Backdated opp + a config with a threshold of 1 forces the alert branch.
        staleOpp();
        Test.startTest();
        Integer total = SentinelMonitor.run(new List<Sentinel_Config__mdt>{ oppConfig() });
        Test.stopTest();
        System.assert(total >= 1, 'Config over threshold should be counted');
    }

    @isTest
    static void catalogAction() {
        Test.startTest();
        List<SentinelCatalogAction.Result> res = SentinelCatalogAction.getCatalog(
            new List<SentinelCatalogAction.Request>{ new SentinelCatalogAction.Request() });
        Test.stopTest();
        System.assertEquals(1, res.size());
        System.assert(res[0].objectCount >= 1, 'At least one watched object expected');
        System.assertNotEquals(null, res[0].catalogJson);
    }

    @isTest
    static void parseIdsSkipsJunk() {
        List<Id> ids = SentinelService.parseIds('  ,notanid,' + UserInfo.getUserId());
        System.assertEquals(1, ids.size(), 'Only the valid Id should survive');
    }
}
