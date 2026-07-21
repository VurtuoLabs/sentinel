/**
 * Write-back action: create a follow-up Task on each given record.
 * Fronted by the Sentinel_CreateFollowUp flow.
 */
public with sharing class SentinelFollowUpAction {

    public class Request {
        @InvocableVariable(required=true) public String recordIds;
        @InvocableVariable public String subject;
        @InvocableVariable public String dueInDays;
    }
    public class Result {
        @InvocableVariable public Integer createdCount;
        @InvocableVariable public String message;
    }

    @InvocableMethod(label='Create Follow Up Tasks' description='Creates a follow-up Task on each given record')
    public static List<Result> followUp(List<Request> reqs) {
        List<Result> out = new List<Result>();
        for (Request req : reqs) {
            Integer due = String.isBlank(req.dueInDays) ? 3 : Integer.valueOf(req.dueInDays);
            String subj = String.isBlank(req.subject) ? 'Follow up (Sentinel)' : req.subject;
            List<Task> tasks = new List<Task>();
            for (Id rid : SentinelService.parseIds(req.recordIds)) {
                tasks.add(buildTask(rid, subj, due));
            }
            if (!tasks.isEmpty()) { insert tasks; }
            Result r = new Result();
            r.createdCount = tasks.size();
            r.message = 'Created ' + tasks.size() + ' follow-up task(s).';
            out.add(r);
        }
        return out;
    }

    private static Task buildTask(Id rid, String subject, Integer dueInDays) {
        Task t = new Task(
            Subject = subject,
            ActivityDate = Date.today().addDays(dueInDays),
            Priority = 'High',
            Status = 'Not Started',
            OwnerId = UserInfo.getUserId()
        );
        String sobjName = rid.getSObjectType().getDescribe().getName();
        if (sobjName == 'Lead' || sobjName == 'Contact') {
            t.WhoId = rid;                              // Leads/Contacts relate via WhoId
        } else if (sobjName == 'Task' || sobjName == 'Event') {
            t.Description = 'Related record: ' + rid;   // activities can't parent activities
        } else {
            t.WhatId = rid;                             // Opportunity, Case, Account, custom
        }
        return t;
    }
}
