// ---- Sentinel demo data ----------------------------------------------------
// Ages Opportunities/Leads/Cases via backdated COMPLETED activities (which drive
// LastActivityDate) and creates standalone OPEN tasks with old ActivityDate.

List<User> owners = [SELECT Id FROM User WHERE IsActive = true AND UserType = 'Standard' ORDER BY CreatedDate LIMIT 4];
if (owners.isEmpty()) { owners = new List<User>{ new User(Id = UserInfo.getUserId()) }; }
Integer oc = owners.size();
Integer pick = 0;

Integer rnd(Integer lo, Integer hi) { return lo + (Integer)Math.floor(Math.random() * (hi - lo + 1)); }

// ---- Opportunities ---------------------------------------------------------
List<String> oppStages = new List<String>{ 'Prospecting','Qualification','Needs Analysis','Value Proposition','Proposal/Price Quote','Negotiation/Review' };
List<Opportunity> opps = new List<Opportunity>();
for (Integer i = 0; i < 24; i++) {
    opps.add(new Opportunity(
        Name = 'Sentinel Demo Opp ' + (i + 1),
        StageName = oppStages[Math.mod(i, oppStages.size())],
        CloseDate = Date.today().addDays(rnd(10, 90)),
        Amount = rnd(5, 250) * 1000,
        OwnerId = owners[Math.mod(pick++, oc)].Id
    ));
}
insert opps;

// ---- Leads -----------------------------------------------------------------
List<String> leadStatus = new List<String>{ 'Open - Not Contacted','Working - Contacted' };
List<String> companies = new List<String>{ 'Acme','Globex','Initech','Umbrella','Soylent','Stark','Wayne','Hooli','Wonka','Cyberdyne' };
List<Lead> leads = new List<Lead>();
for (Integer i = 0; i < 20; i++) {
    leads.add(new Lead(
        LastName = 'Prospect ' + (i + 1),
        FirstName = 'Demo',
        Company = companies[Math.mod(i, companies.size())],
        Status = leadStatus[Math.mod(i, leadStatus.size())],
        OwnerId = owners[Math.mod(pick++, oc)].Id
    ));
}
insert leads;

// ---- Cases -----------------------------------------------------------------
List<String> casePriority = new List<String>{ 'Low','Medium','High' };
List<String> caseOrigin = new List<String>{ 'Web','Phone','Email' };
List<Case> cases = new List<Case>();
for (Integer i = 0; i < 26; i++) {
    cases.add(new Case(
        Subject = 'Sentinel Demo Case ' + (i + 1),
        Priority = casePriority[Math.mod(i, casePriority.size())],
        Status = 'New',
        Origin = caseOrigin[Math.mod(i, caseOrigin.size())],
        OwnerId = owners[Math.mod(pick++, oc)].Id
    ));
}
insert cases;

// ---- Aging completed activities (drive LastActivityDate) -------------------
List<Task> aging = new List<Task>();
for (Opportunity o : opps) {
    aging.add(new Task(WhatId = o.Id, Subject = 'Aged touch', Status = 'Completed',
        Priority = 'Normal', ActivityDate = Date.today().addDays(-rnd(15, 130))));
}
for (Lead l : leads) {
    aging.add(new Task(WhoId = l.Id, Subject = 'Aged touch', Status = 'Completed',
        Priority = 'Normal', ActivityDate = Date.today().addDays(-rnd(12, 95))));
}
for (Case c : cases) {
    aging.add(new Task(WhatId = c.Id, Subject = 'Aged touch', Status = 'Completed',
        Priority = 'Normal', ActivityDate = Date.today().addDays(-rnd(8, 85))));
}
insert aging;

// ---- Standalone OPEN tasks (Task board) ------------------------------------
List<String> taskPriority = new List<String>{ 'Low','Normal','High' };
List<String> openStatus = new List<String>{ 'Not Started','In Progress' };
List<Task> openTasks = new List<Task>();
for (Integer i = 0; i < 18; i++) {
    openTasks.add(new Task(
        Subject = 'Sentinel Demo Task ' + (i + 1),
        Status = openStatus[Math.mod(i, openStatus.size())],
        Priority = taskPriority[Math.mod(i, taskPriority.size())],
        ActivityDate = Date.today().addDays(-rnd(6, 60)),
        OwnerId = owners[Math.mod(pick++, oc)].Id
    ));
}
insert openTasks;

System.debug('Seeded: ' + opps.size() + ' opps, ' + leads.size() + ' leads, ' +
    cases.size() + ' cases, ' + openTasks.size() + ' open tasks, ' + aging.size() + ' aging activities.');
