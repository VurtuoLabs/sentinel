/**
 * Single-object staleness check. Thin invocable wrapper over SentinelService,
 * fronted by the Sentinel_HealthCheck flow for the agent.
 */
public with sharing class SentinelHealthCheck {

    public class Request {
        @InvocableVariable(required=true)
        public String objectApiName;
        @InvocableVariable
        public String ownerScope; // 'mine' scopes to the running user; anything else = all
    }

    public class Result {
        @InvocableVariable public String staleRecordsJson;
        @InvocableVariable public String summaryJson;
        @InvocableVariable public String label;
        @InvocableVariable public Integer staleCount;
    }

    @InvocableMethod(label='Check Record Health' description='Returns stale records for a configured standard object')
    public static List<Result> check(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            String scope = String.isBlank(req.ownerScope) ? 'all' : req.ownerScope.toLowerCase();
            SentinelService.Report rep = SentinelService.runCheck(req.objectApiName, scope);
            Result r = new Result();
            r.staleCount = rep.staleCount;
            r.label = rep.label;
            r.staleRecordsJson = JSON.serialize(rep.records);
            r.summaryJson = JSON.serialize(rep.summary);
            results.add(r);
        }
        return results;
    }
}
