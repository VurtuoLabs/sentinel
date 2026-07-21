/**
 * SentinelMonitor — scheduled proactive sweep. Runs every active config, posts a
 * digest to the running user's Chatter feed, and raises a custom notification for
 * any config whose stale count meets or exceeds its Threshold_Alert__c.
 *
 * Schedule with:
 *   System.schedule('Sentinel Daily Monitor', '0 0 7 * * ?', new SentinelMonitor());
 */
public with sharing class SentinelMonitor implements Schedulable {

    public void execute(SchedulableContext sc) {
        run();
    }

    public static Integer run() {
        return run(SentinelService.getActiveConfigs());
    }

    public static Integer run(List<Sentinel_Config__mdt> configs) {
        List<String> lines = new List<String>();
        List<Messaging.CustomNotification> notes = new List<Messaging.CustomNotification>();
        Id notifTypeId = getNotificationTypeId();
        Id me = UserInfo.getUserId();
        Integer grandTotal = 0;

        for (Sentinel_Config__mdt cfg : configs) {
            SentinelService.Report rep = SentinelService.runCheck(cfg, 'all');
            grandTotal += rep.staleCount;
            lines.add(rep.label + ' (' + rep.objectApiName + '): ' + rep.staleCount + ' at-risk');

            if (cfg.Threshold_Alert__c != null && rep.staleCount >= cfg.Threshold_Alert__c && notifTypeId != null) {
                Messaging.CustomNotification n = new Messaging.CustomNotification();
                n.setTitle('Sentinel: ' + rep.label + ' needs attention');
                n.setBody(rep.staleCount + ' ' + rep.label + ' records are at-risk (threshold ' +
                    Integer.valueOf(cfg.Threshold_Alert__c) + ').');
                n.setNotificationTypeId(notifTypeId);
                n.setTargetId(me);
                notes.add(n);
            }
        }

        try {
            insert new FeedItem(
                ParentId = me,
                Body = 'Sentinel daily health digest — ' + grandTotal + ' records at-risk\n' +
                    String.join(lines, '\n')
            );
        } catch (Exception e) {
            // Chatter may be disabled in the org; the digest is best-effort.
        }

        for (Messaging.CustomNotification n : notes) {
            try { n.send(new Set<String>{ String.valueOf(me) }); } catch (Exception e) { /* best-effort */ }
        }
        return grandTotal;
    }

    private static Id getNotificationTypeId() {
        List<CustomNotificationType> types = [
            SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'Sentinel_Alert' LIMIT 1
        ];
        return types.isEmpty() ? null : types[0].Id;
    }
}
