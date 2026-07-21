/**
 * Write-back action: reassign a comma-separated list of record Ids to a user
 * (defaults to the running user). Fronted by the Sentinel_Reassign flow.
 */
public with sharing class SentinelReassignAction {

    public class Request {
        @InvocableVariable(required=true) public String recordIds;
        @InvocableVariable public String targetUserId; // defaults to running user
    }
    public class Result {
        @InvocableVariable public Integer updatedCount;
        @InvocableVariable public String message;
    }

    @InvocableMethod(label='Reassign Records' description='Reassigns the given records to a user (defaults to the running user)')
    public static List<Result> reassign(List<Request> reqs) {
        List<Result> out = new List<Result>();
        for (Request req : reqs) {
            Id target = String.isBlank(req.targetUserId) ? UserInfo.getUserId() : (Id) req.targetUserId;
            List<SObject> updates = new List<SObject>();
            for (Id rid : SentinelService.parseIds(req.recordIds)) {
                SObject so = rid.getSObjectType().newSObject(rid);
                so.put('OwnerId', target);
                updates.add(so);
            }
            if (!updates.isEmpty()) { update updates; }
            Result r = new Result();
            r.updatedCount = updates.size();
            r.message = 'Reassigned ' + updates.size() + ' record(s).';
            out.add(r);
        }
        return out;
    }
}
