/**
 * Read-only controller for the Sentinel LWC dashboard. Returns per-object health
 * with freshness bands, top owners, and the record list — all from SentinelService.
 */
public with sharing class SentinelDashboardController {

    public class ObjectHealth {
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String label;
        @AuraEnabled public Integer staleCount;
        @AuraEnabled public Integer thresholdDays;
        @AuraEnabled public Integer aging;
        @AuraEnabled public Integer stale;
        @AuraEnabled public Integer critical;
        @AuraEnabled public List<SentinelService.GroupCount> topOwners;
        @AuraEnabled public List<SentinelService.RecordInfo> records;
    }

    public class Overview {
        @AuraEnabled public Integer totalAtRisk;
        @AuraEnabled public Integer objectCount;
        @AuraEnabled public Integer critical;
        @AuraEnabled public List<ObjectHealth> objects;
    }

    @AuraEnabled(cacheable=true)
    public static Overview getOverview(String ownerScope) {
        String scope = String.isBlank(ownerScope) ? 'all' : ownerScope.toLowerCase();
        Overview ov = new Overview();
        ov.objects = new List<ObjectHealth>();
        ov.totalAtRisk = 0;
        ov.critical = 0;

        for (Sentinel_Config__mdt cfg : SentinelService.getActiveConfigs()) {
            SentinelService.Report rep = SentinelService.runCheck(cfg, scope);
            ObjectHealth oh = new ObjectHealth();
            oh.objectApiName = rep.objectApiName;
            oh.label = rep.label;
            oh.staleCount = rep.staleCount;
            oh.thresholdDays = rep.thresholdDays;
            oh.aging = 0; oh.stale = 0; oh.critical = 0;
            for (SentinelService.GroupCount g : rep.summary.byBand) {
                if (g.key == 'Aging') { oh.aging = g.count; }
                else if (g.key == 'Stale') { oh.stale = g.count; }
                else if (g.key == 'Critical') { oh.critical = g.count; }
            }
            oh.topOwners = rep.summary.byOwner;
            oh.records = rep.records;
            ov.objects.add(oh);
            ov.totalAtRisk += rep.staleCount;
            ov.critical += oh.critical;
        }
        ov.objectCount = ov.objects.size();
        return ov;
    }
}
