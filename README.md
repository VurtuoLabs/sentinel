# Sentinel

**A config-driven Salesforce app that surfaces stale, at-risk records across any standard object — with a colorful dashboard, a five-sub-agent Agentforce assistant, one-click triage, and a daily proactive monitor. Zero per-object code.**

Ask Sentinel *"what should I work on first?"*, open the **Sentinel** app for a live health radar, or let the daily monitor push you a digest. Adding a new object to watch is a metadata record — not a code change.

---

> ## ⚠️ Before you deploy to a new org
>
> Three things to configure — the deploy will succeed without them, but the agent won't behave correctly until they're set:
>
> 1. **Agent user.** Sentinel ships as an **Employee Agent** (internal users, no channel setup, no agent user required). If you switch it to a customer-facing **Service Agent**, edit [`Sentinel.agent`](force-app/main/default/aiAuthoringBundles/Sentinel/Sentinel.agent): set `agent_type: "AgentforceServiceAgent"` and add an `access:` block with a **real Einstein Agent User** — publishing with a missing/placeholder user fails with *"Internal Error, try again later."*
> 2. **Permission set.** Assign **`Sentinel_User`** to the agent's running user **and** to end users — otherwise actions return no data or are blocked.
> 3. **Config records.** Review the [`Sentinel_Config.*`](force-app/main/default/customMetadata/) metadata records so the watched objects, date fields, thresholds, and filters match your org. (The shipped `Date_Field__c` values must be **queryable on that object** — e.g. `LastActivityDate` exists on Opportunity/Lead but not everywhere.)
>
> The same checklist lives at the top of `Sentinel.agent` and `manifest/package.xml`.

---

## Why it's effective

Most record-hygiene solutions hard-code one query per object. Sentinel inverts that: **all object-specific knowledge lives in a Custom Metadata Type**, and a single Apex service reads that config to build every query at runtime.

| Property | How Sentinel achieves it |
|---|---|
| **No per-object code** | One `SentinelService` serves Case, Opportunity, Lead, Task, and anything else you configure. |
| **No storage overhead** | Config ships as Custom Metadata — deploys with the app, packageable, no records to seed. |
| **Change without deploying Apex** | Thresholds, date fields, sort, filters, and alert levels are metadata edits. |
| **Reliable agent actions** | The agent calls Apex through thin flows (`flow://`) — the pattern Agentforce treats as most reliable. |
| **Governor-safe & injection-safe** | Queries are capped and ordered; every identifier from config is validated against an allowlist. |

---

## Architecture

```
Conversation ─ Agentforce "Sentinel" Employee Agent
                 └─ router → 5 sub-agents (see below)
Automation ── Daily SentinelMonitor → Chatter digest + threshold notifications
UI ────────── "Sentinel" Lightning app → colorful LWC dashboard (freshness bands)
Actions ───── 5 flow-fronted invocables: HealthCheck · Rollup · Reassign · FollowUp · Catalog
Logic ─────── SentinelService (shared engine) + focused controllers
Data ──────── Sentinel_Config__mdt (one record per watched object)
```

### Data — `Sentinel_Config__mdt`

| Field | Purpose |
|---|---|
| `Object_API_Name__c` | Object to monitor (`Case`, `Opportunity`, `Lead`, `Task`). |
| `Date_Field__c` | Field measuring staleness (`LastActivityDate`, `LastModifiedDate`, `ActivityDate`). |
| `Stale_Days__c` | Days before a record counts as at-risk. |
| `Owner_Field__c` | Usually `OwnerId`; resolves `Owner.Name` automatically. |
| `Priority_Field__c` | Optional field to surface (`Priority`, `StageName`, `Status`). |
| `Name_Field__c` | Display-name field — `Name`, or `CaseNumber` / `Subject`. |
| `Filter_Criteria__c` | Optional extra `WHERE` fragment (`IsClosed = false`). |
| `Sort_Field__c` / `Sort_Direction__c` | Optional ordering (defaults to date, oldest first). |
| `Threshold_Alert__c` | Daily monitor raises a notification at/above this count. |
| `Is_Active__c` | Unchecked configs are skipped by rollups and the monitor. |
| `Label__c` | Friendly name shown to users (`Active Pipeline`). |

Four records ship: **Active Pipeline** (Opportunity), **Open Cases** (Case), **Working Leads** (Lead), **Open Tasks** (Task).

### Logic — `SentinelService`

One engine builds each query from config and returns an enriched report per record: **freshness band** (Aging / Stale / Critical at 1×/2×/3× the threshold), **deep link**, resolved **owner name**, **age in days**, plus summaries grouped by owner, priority, and band. Every entry point reuses it.

### The agent — 5 sub-agents

A hub-and-spoke Employee Agent; the router picks a specialist per utterance:

| Sub-agent | Handles | Backing |
|---|---|---|
| **Record Health** | "stale opps?", "check my leads" | `Check_Health`, `Check_All` |
| **Focus / Prioritize** | "what should I work on first?", "morning briefing" | `Check_All` scoped to you → ranks → hands off to Triage |
| **Triage** | "reassign these", "create follow-ups" | `Reassign_Records`, `Create_Follow_Up` — confirms first |
| **Catalog** | "what can you check?", "how does staleness work?" | `List_Watched_Objects` |
| **Coach** | "how do I keep my pipeline fresh?" | best-practice advice, then offers real data |

Focus and Coach **transition** into other sub-agents, so one thread can flow check → prioritize → act.

### UI — the `Sentinel` Lightning app

A colorful LWC dashboard (`sentinelDashboard` + `sentinelStatCard`): gradient header with an **All / Mine** scope toggle and refresh, three KPI hero tiles, and a card per object showing a stacked **freshness-band bar**, band chips, the idle threshold, and top owners.

### Automation — `SentinelMonitor`

A scheduled sweep that runs every active config, posts a **Chatter digest**, and raises a **Sentinel Alert** custom notification for any config at/above its `Threshold_Alert__c`.

---

## Install

```bash
sf org login web --alias my-org --set-default

# Deploy everything (uses the manifest):
sf project deploy start --manifest manifest/package.xml --json
#   …or just: sf project deploy start --source-dir force-app --json

# Grant access — end users AND the agent's running user
sf org assign permset --name Sentinel_User

# Publish & activate the agent (see "Before you deploy" first)
sf agent validate authoring-bundle --api-name Sentinel --json
sf agent publish  authoring-bundle --api-name Sentinel --json
sf agent activate --api-name Sentinel --json

# Schedule the daily monitor (anonymous Apex)
echo "System.schedule('Sentinel Daily Monitor','0 0 7 * * ?', new SentinelMonitor());" \
  | sf apex run
```

> **Note:** `sf project deploy start` deploys the agent bundle as an editable **draft**; `sf agent publish` compiles it into a running Bot. If the CLI's Einstein authoring endpoint is unreachable, you can **Publish → Activate from Agentforce Studio** in the browser instead.

---

## Using Sentinel in the Salesforce UI

- **Dashboard (works immediately):** App Launcher → **Sentinel**, or the **Sentinel** tab. Drop the `sentinelDashboard` component on any Home/App/Record page via Lightning App Builder.
- **Agent (after publish + activate):** in **Agentforce Studio → Sentinel → Connections**, add the **Salesforce (Employee)** channel and enable it for `Sentinel_User` holders. It then appears as the **Agentforce assistant panel** (sparkle icon, top-right utility bar) on any Lightning page — and optionally in **Slack**.

---

## Demo data

[`scripts/seedData.apex`](scripts/seedData.apex) creates ~60 at-risk records across Opportunity, Lead, and Task by backdating **completed activities** (which drive `LastActivityDate`) and setting past `ActivityDate` on open tasks. Re-run any time:

```bash
sf apex run --file scripts/seedData.apex
```

---

## Known limitations

- **Ageing Cases** depends on the org: Case needs a queryable staleness date. Where `LastActivityDate` is absent and audit-field writes are disabled, seeded Cases can't be backdated — the Case board reads 0 until cases age naturally. Opportunity/Lead/Task populate fully.
- **`ownerScope=mine`** filters on the owner field equalling the running user; use it only where that field references a user.
- **Dynamic SOQL** is assembled from metadata. Config is developer/admin-controlled and every identifier is allowlist-validated, but treat `Filter_Criteria__c` as trusted developer input, never end-user input.
- **CLI publish endpoint.** For some org types the CLI routes `sf agent publish` to `test.api.salesforce.com`; if that host is unreachable, publish from Agentforce Studio in the browser instead.

---

## Project layout

```
manifest/package.xml                   # deploy manifest + config checklist
scripts/seedData.apex                  # demo data
force-app/main/default/
├── objects/Sentinel_Config__mdt/      # Custom Metadata Type + 12 fields
├── customMetadata/                    # one record per watched object
├── classes/                           # SentinelService + 5 actions + controller + monitor + tests
├── flows/                             # 5 flow-fronted action targets
├── notificationtypes/                 # Sentinel_Alert custom notification
├── lwc/                               # sentinelDashboard + sentinelStatCard
├── flexipages/  tabs/  applications/  # Sentinel app page, tab, Lightning app
├── permissionsets/                    # Sentinel_User
└── aiAuthoringBundles/Sentinel/       # the Sentinel agent (5 sub-agents)
```

## License

[MIT](LICENSE) © 2026 Alex Imperiale
