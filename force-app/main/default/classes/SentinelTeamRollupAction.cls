/**
 * Manager view: aggregates at-risk counts by owner across every active
 * configured object (or one, if given), for "which reps have the most stale
 * pipeline" style questions. Fronted by the Sentinel_TeamRollup flow.
 */
public with sharing class SentinelTeamRollupAction {

    public class Request {
        @InvocableVariable public String objectApiName; // optional; blank = every active config
    }
    public class Result {
        @InvocableVariable public String leaderboardJson;
        @InvocableVariable public Integer ownerCount;
        @InvocableVariable public Integer totalCount;
    }

    @InvocableMethod(label='Team Rollup' description='At-risk record counts grouped by owner, across every watched object')
    public static List<Result> rollup(List<Request> reqs) {
        List<Result> out = new List<Result>();
        for (Request req : reqs) {
            List<Sentinel_Config__mdt> configs = String.isBlank(req.objectApiName)
                ? SentinelService.getActiveConfigs()
                : new List<Sentinel_Config__mdt>{ SentinelService.getConfig(req.objectApiName) };

            Map<String, Integer> ownerTotals = new Map<String, Integer>();
            Integer total = 0;
            for (Sentinel_Config__mdt cfg : configs) {
                SentinelService.Report rep = SentinelService.runCheck(cfg, 'all');
                total += rep.staleCount;
                for (SentinelService.GroupCount gc : rep.summary.byOwner) {
                    ownerTotals.put(gc.key, (ownerTotals.containsKey(gc.key) ? ownerTotals.get(gc.key) : 0) + gc.count);
                }
            }

            List<SentinelService.GroupCount> leaderboard = SentinelService.toGroupCounts(ownerTotals);
            Result r = new Result();
            r.leaderboardJson = JSON.serialize(leaderboard);
            r.ownerCount = leaderboard.size();
            r.totalCount = total;
            out.add(r);
        }
        return out;
    }
}
