/**
 * Write-back action: snoozes a comma-separated list of record Ids so they drop
 * off at-risk results until a given date. Fronted by the Sentinel_Snooze flow.
 */
public with sharing class SentinelSnoozeAction {

    public class Request {
        @InvocableVariable(required=true) public String recordIds;
        @InvocableVariable public Integer snoozeDays; // defaults to 7
        @InvocableVariable public String reason;
    }
    public class Result {
        @InvocableVariable public Integer snoozedCount;
        @InvocableVariable public String message;
    }

    @InvocableMethod(label='Snooze Records' description='Stops nagging about the given records until a future date')
    public static List<Result> snooze(List<Request> reqs) {
        List<Result> out = new List<Result>();
        for (Request req : reqs) {
            Integer days = req.snoozeDays == null ? 7 : req.snoozeDays;
            Date until = Date.today().addDays(days);
            List<Sentinel_Snooze__c> rows = new List<Sentinel_Snooze__c>();
            for (Id rid : SentinelService.parseIds(req.recordIds)) {
                rows.add(new Sentinel_Snooze__c(
                    Record_Id__c = String.valueOf(rid),
                    Object_API_Name__c = rid.getSObjectType().getDescribe().getName(),
                    Snoozed_Until__c = until,
                    Reason__c = req.reason,
                    Snoozed_By__c = UserInfo.getUserId()
                ));
            }
            if (!rows.isEmpty()) { insert rows; }
            Result r = new Result();
            r.snoozedCount = rows.size();
            r.message = 'Snoozed ' + rows.size() + ' record(s) until ' + until.format() + '.';
            out.add(r);
        }
        return out;
    }
}
