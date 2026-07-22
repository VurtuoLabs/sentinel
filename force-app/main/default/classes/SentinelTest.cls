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
        System.assertNotEquals(null, ri.lastModifiedDate, 'LastModifiedDate should always be populated');
        System.assert(ri.explanation.contains('threshold'), 'Explanation should describe the threshold math');
        System.assertEquals(true, ri.isSingleThreaded, 'Opportunity with zero contact roles is single-threaded');
    }

    @isTest
    static void snoozedRecordsAreExcluded() {
        Opportunity o = staleOpp();
        insert new Sentinel_Snooze__c(
            Record_Id__c = o.Id,
            Object_API_Name__c = 'Opportunity',
            Snoozed_Until__c = Date.today().addDays(7),
            Reason__c = 'Still working it'
        );
        Test.startTest();
        SentinelService.Report rep = SentinelService.runCheck(oppConfig(), 'all');
        Test.stopTest();
        for (SentinelService.RecordInfo ri : rep.records) {
            System.assertNotEquals(o.Id, (Id) ri.id, 'Snoozed record should be excluded from at-risk results');
        }
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

    @isTest
    static void snoozeActionInsertsRow() {
        Opportunity o = staleOpp();
        SentinelSnoozeAction.Request req = new SentinelSnoozeAction.Request();
        req.recordIds = o.Id;
        req.reason = 'Still working it';
        Test.startTest();
        List<SentinelSnoozeAction.Result> res = SentinelSnoozeAction.snooze(
            new List<SentinelSnoozeAction.Request>{ req });
        Test.stopTest();
        System.assertEquals(1, res[0].snoozedCount);
        System.assertEquals(1, [SELECT COUNT() FROM Sentinel_Snooze__c WHERE Record_Id__c = :String.valueOf(o.Id)]);
    }

    @isTest
    static void logActivityActionCreatesTask() {
        Opportunity o = staleOpp();
        SentinelLogActivityAction.Request req = new SentinelLogActivityAction.Request();
        req.recordIds = o.Id;
        req.note = 'Called them, they need a revised quote';
        Test.startTest();
        List<SentinelLogActivityAction.Result> res = SentinelLogActivityAction.log(
            new List<SentinelLogActivityAction.Request>{ req });
        Test.stopTest();
        System.assertEquals(1, res[0].loggedCount);
        System.assertEquals(1, [SELECT COUNT() FROM Task WHERE WhatId = :o.Id AND Status = 'Completed']);
    }

    @isTest
    static void whatChangedActionHandlesNoPriorSnapshot() {
        staleOpp();
        SentinelWhatChangedAction.Request req = new SentinelWhatChangedAction.Request();
        req.objectApiName = 'Opportunity';
        Test.startTest();
        List<SentinelWhatChangedAction.Result> res = SentinelWhatChangedAction.check(
            new List<SentinelWhatChangedAction.Request>{ req });
        Test.stopTest();
        System.assertNotEquals(null, res[0].deltaJson);
        System.assert(res[0].message.contains('no prior snapshot'), 'First run should note there is nothing to compare against');
    }

    @isTest
    static void accountContextActionResolvesAccount() {
        Account acct = new Account(Name = 'Sentinel Test Account');
        insert acct;
        Case c = new Case(AccountId = acct.Id, Status = 'New');
        insert c;
        Opportunity o = new Opportunity(
            Name = 'Sentinel Ctx Opp', AccountId = acct.Id,
            StageName = 'Prospecting', CloseDate = Date.today().addDays(30)
        );
        insert o;

        SentinelAccountContextAction.Request req = new SentinelAccountContextAction.Request();
        req.recordId = o.Id;
        Test.startTest();
        List<SentinelAccountContextAction.Result> res = SentinelAccountContextAction.context(
            new List<SentinelAccountContextAction.Request>{ req });
        Test.stopTest();
        System.assertEquals('Sentinel Test Account', res[0].accountName);
        System.assertEquals(1, res[0].openCaseCount);
        System.assertEquals(1, res[0].openOpportunityCount);
    }

    /** Ages an Opportunity via a backdated completed Task, so it goes stale under the
     *  real deployed Sentinel_Config__mdt (which keys off LastActivityDate, not CreatedDate). */
    private static Opportunity staleOppViaActivity() {
        Opportunity o = new Opportunity(
            Name = 'Sentinel Rollup Opp', StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30), Amount = 5000
        );
        insert o;
        insert new Task(WhatId = o.Id, Subject = 'Aged touch', Status = 'Completed',
            ActivityDate = Date.today().addDays(-100));
        return o;
    }

    @isTest
    static void teamRollupActionAggregatesByOwner() {
        staleOppViaActivity();
        SentinelTeamRollupAction.Request req = new SentinelTeamRollupAction.Request();
        req.objectApiName = 'Opportunity';
        Test.startTest();
        List<SentinelTeamRollupAction.Result> res = SentinelTeamRollupAction.rollup(
            new List<SentinelTeamRollupAction.Request>{ req });
        Test.stopTest();
        System.assert(res[0].totalCount >= 1, 'At least the backdated opp should be counted');
        System.assertNotEquals(null, res[0].leaderboardJson);
    }

    @isTest
    static void monitorWritesSnapshotAndEscalates() {
        staleOpp();
        Test.startTest();
        SentinelMonitor.run(new List<Sentinel_Config__mdt>{ oppConfig() });
        // Second run same day should update the existing snapshot row, not duplicate it.
        SentinelMonitor.run(new List<Sentinel_Config__mdt>{ oppConfig() });
        Test.stopTest();
        System.assertEquals(1, [SELECT COUNT() FROM Sentinel_Snapshot__c WHERE Object_API_Name__c = 'Opportunity']);
    }

    @isTest
    static void dashboardTrendsReturnsSnapshotHistory() {
        insert new Sentinel_Snapshot__c(
            Object_API_Name__c = 'Opportunity', Label__c = 'Active Pipeline',
            Snapshot_Date__c = Date.today().addDays(-1), Stale_Count__c = 5, Critical_Count__c = 2
        );
        insert new Sentinel_Snapshot__c(
            Object_API_Name__c = 'Opportunity', Label__c = 'Active Pipeline',
            Snapshot_Date__c = Date.today(), Stale_Count__c = 7, Critical_Count__c = 3
        );
        Test.startTest();
        List<SentinelDashboardController.ObjectTrend> trends = SentinelDashboardController.getTrends(14);
        Test.stopTest();
        System.assertEquals(1, trends.size());
        System.assertEquals(2, trends[0].points.size());
    }

    @isTest
    static void dashboardLeaderboardAggregatesOwners() {
        staleOppViaActivity();
        Test.startTest();
        List<SentinelService.GroupCount> board = SentinelDashboardController.getLeaderboard('Opportunity');
        Test.stopTest();
        System.assert(!board.isEmpty(), 'Running user should appear on the leaderboard');
    }

    @isTest
    static void dashboardSnoozedResolvesDisplayName() {
        Opportunity o = staleOppViaActivity();
        insert new Sentinel_Snooze__c(
            Record_Id__c = o.Id, Object_API_Name__c = 'Opportunity',
            Snoozed_Until__c = Date.today().addDays(7), Reason__c = 'Testing'
        );
        Test.startTest();
        List<SentinelDashboardController.SnoozedRecord> snoozed = SentinelDashboardController.getSnoozed();
        Test.stopTest();
        System.assertEquals(1, snoozed.size());
        System.assertEquals(o.Name, snoozed[0].displayName, 'Should resolve the Opportunity Name, not just echo the Id');
    }

    @isTest
    static void dashboardPipelineValueSumsAmounts() {
        staleOppViaActivity();
        Test.startTest();
        SentinelDashboardController.PipelineValue pv = SentinelDashboardController.getPipelineValue();
        Test.stopTest();
        System.assert(pv.totalAmount >= 5000, 'Backdated opp amount should roll into the total');
    }

    @isTest
    static void dashboardSingleThreadedFlagsZeroContactRoles() {
        staleOppViaActivity();
        Test.startTest();
        List<SentinelService.RecordInfo> flagged = SentinelDashboardController.getSingleThreaded();
        Test.stopTest();
        System.assert(!flagged.isEmpty(), 'Opp with zero contact roles should be flagged single-threaded');
    }

    @isTest
    static void dashboardActivityGapsSplitsRecords() {
        staleOppViaActivity(); // has a completed Task, so it lands in wentCold, not neverContacted
        Test.startTest();
        List<SentinelDashboardController.ActivityGaps> gaps = SentinelDashboardController.getActivityGaps();
        Test.stopTest();
        Boolean found = false;
        for (SentinelDashboardController.ActivityGaps ag : gaps) {
            if (ag.objectApiName == 'Opportunity') {
                found = true;
                System.assert(ag.wentColdCount >= 1, 'Opp with a logged activity should count as went-cold, not never-contacted');
            }
        }
        System.assert(found, 'Opportunity config should be represented in activity gaps');
    }
}
