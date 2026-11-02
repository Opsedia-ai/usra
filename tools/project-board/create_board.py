"""Builds the Usra roadmap board in the Opsedia-ai org (GitHub Projects v2)."""
import json
import subprocess
import sys

ORG = "Opsedia-ai"
REPO = "Usra_medical_history"
TITLE = "Usra roadmap"


def gql(query, **vars):
    args = ["gh", "api", "graphql", "-f", f"query={query}"]
    for k, v in vars.items():
        args += ["-F" if isinstance(v, int) else "-f", f"{k}={v}"]
    out = subprocess.run(args, capture_output=True, text=True)
    if out.returncode:
        sys.exit(f"GraphQL failed: {out.stderr}\n{query}")
    return json.loads(out.stdout)["data"]


def gql_json(query, variables):
    body = json.dumps({"query": query, "variables": variables})
    out = subprocess.run(["gh", "api", "graphql", "--input", "-"], input=body,
                         capture_output=True, text=True)
    if out.returncode or "errors" in out.stdout[:20]:
        sys.exit(f"GraphQL failed: {out.stdout} {out.stderr}")
    return json.loads(out.stdout)["data"]


STATUS = [("Backlog", "GRAY"), ("Ready", "BLUE"), ("In progress", "YELLOW"),
          ("In review", "ORANGE"), ("Blocked", "RED"), ("Done", "GREEN")]
MILESTONES = [
    ("M0 Foundations", "App shell, design system, encrypted DB, CI"),
    ("M1 Core records", "Profiles, timeline, doctors, insurance, attachments"),
    ("M2 Medicines + reminders", "OCR, medicines, alarms, widget"),
    ("M3 Family care", "Growth, vaccines, infant, pregnancy, elder mode"),
    ("M4 Money + backup", "Spending dashboard, encrypted backup"),
    ("M5 Launch v1", "Stores, privacy, legal, Egypt beta"),
    ("M6 Cloud + AI", "Supabase, E2EE sync, AI Doctor"),
    ("M7 Partners", "Clinic portal, in-region hosting"),
]
AREAS = [("App", "BLUE"), ("Backend", "PURPLE"), ("Design & docs", "PINK"),
         ("Founder tasks", "ORANGE")]

# (title, milestone index, area, status, body)
DRAFTS = [
    ("Product proposal, research, technical design, screen designs", 0, "Design & docs", "Done",
     "docs/ and design/ in the repo."),
    ("Doctors directory with phone numbers and visit fees", 1, "App", "Ready", ""),
    ("Insurance cards (multiple per person) + WhatsApp share", 1, "App", "Backlog", ""),
    ("Photo attachments on records", 1, "App", "Backlog", ""),
    ("On-device OCR for prescriptions and medicine boxes", 2, "App", "Backlog", ""),
    ("Medicines with photos and schedules", 2, "App", "Backlog", ""),
    ("Reliable alarms and reminders (AlarmKit on iOS 26+)", 2, "App", "Backlog",
     "Exit: reminders fire on 3 budget Android phones."),
    ("Home-screen widget and dose log", 2, "App", "Backlog", ""),
    ("Child growth charts and vaccination schedule", 3, "App", "Backlog", ""),
    ("Infant development log", 3, "App", "Backlog", ""),
    ("Pregnancy mode", 3, "App", "Backlog", ""),
    ("Elder Simple Mode and tutorials with Dr. Usra", 3, "App", "Backlog", ""),
    ("Emergency card", 3, "App", "Backlog", ""),
    ("Automatic follow-ups by condition and age", 3, "App", "Backlog", ""),
    ("Spending dashboard per person and family", 4, "App", "Backlog", ""),
    ("Encrypted backup, restore and recovery key", 4, "App", "Backlog",
     "Exit: restore works on a new phone."),
    ("Store listings, privacy labels and health declarations", 5, "Founder tasks", "Backlog", ""),
    ("Legal review (Egypt PDPL, KSA SFDA, UAE)", 5, "Founder tasks", "Backlog", ""),
    ("Closed beta in Egypt", 5, "Founder tasks", "Backlog", ""),
    ("Supabase accounts and E2EE sync", 6, "Backend", "Backlog", ""),
    ("Caregiver alerts", 6, "Backend", "Backlog", ""),
    ("Cloud OCR fallback (with consent)", 6, "Backend", "Backlog", ""),
    ("AI Doctor with credits and subscription", 6, "Backend", "Backlog", ""),
    ("Clinic portal, ads and doctor recommendations", 7, "Backend", "Backlog", ""),
    ("Appointment reminders from clinics", 7, "Backend", "Backlog", ""),
    ("Self-hosted Supabase in-region", 7, "Backend", "Backlog", ""),
    ("Install Xcode (iOS builds)", 0, "Founder tasks", "Ready", ""),
    ("Install Android Studio", 0, "Founder tasks", "Ready", ""),
    ("Restart / fix Docker Desktop (local Supabase)", 0, "Founder tasks", "Ready", ""),
    ("Apple Developer enrolment as an organisation (D-U-N-S)", 5, "Founder tasks", "Ready",
     "Start early: D-U-N-S can take weeks."),
    ("Google Play developer account (organisation)", 5, "Founder tasks", "Backlog", ""),
    ("Create the Supabase project", 6, "Founder tasks", "Backlog",
     "Share only the project URL and anon key; never the service-role key."),
]

# PR number -> (milestone index, area, status)
PRS = {1: (0, "App", "Done"), 2: (0, "Backend", "In review"), 3: (1, "App", "In review")}


def main():
    owner = gql("query($l:String!){organization(login:$l){id repository(name:\"%s\"){id}}}" % REPO, l=ORG)
    org_id = owner["organization"]["id"]
    repo_id = owner["organization"]["repository"]["id"]

    project = gql_json(
        "mutation($o:ID!,$t:String!,$r:ID!){createProjectV2(input:{ownerId:$o,title:$t,repositoryId:$r}){projectV2{id number url}}}",
        {"o": org_id, "t": TITLE, "r": repo_id})["createProjectV2"]["projectV2"]
    pid = project["id"]
    gql_json("mutation($p:ID!,$d:String!,$r:String!){updateProjectV2(input:{projectId:$p,shortDescription:$d,readme:$r}){projectV2{id}}}",
             {"p": pid, "d": "Usra (أسرة) family medical history app: milestones, PRs and founder tasks",
              "r": "Status of the Usra app. Group the board by **Status**; filter by **Phase** or **Area**.\n\nPlan: docs/pdf/04-technical-design.pdf (Build plan)."})

    fields = gql_json("query($p:ID!){node(id:$p){...on ProjectV2{fields(first:30){nodes{...on ProjectV2SingleSelectField{id name}}}}}}",
                      {"p": pid})["node"]["fields"]["nodes"]
    status_id = next(f["id"] for f in fields if f.get("name") == "Status")

    def opts(items):
        return [{"name": n, "color": c, "description": d} for n, c, d in items]

    status = gql_json(
        "mutation($f:ID!,$o:[ProjectV2SingleSelectFieldOptionInput!]){updateProjectV2Field(input:{fieldId:$f,singleSelectOptions:$o}){projectV2Field{...on ProjectV2SingleSelectField{options{id name}}}}}",
        {"f": status_id, "o": opts([(n, c, "") for n, c in STATUS])})["updateProjectV2Field"]["projectV2Field"]["options"]
    status = {o["name"]: o["id"] for o in status}

    def new_field(name, options):
        f = gql_json(
            "mutation($p:ID!,$n:String!,$o:[ProjectV2SingleSelectFieldOptionInput!]){createProjectV2Field(input:{projectId:$p,dataType:SINGLE_SELECT,name:$n,singleSelectOptions:$o}){projectV2Field{...on ProjectV2SingleSelectField{id options{id name}}}}}",
            {"p": pid, "n": name, "o": opts(options)})["createProjectV2Field"]["projectV2Field"]
        return f["id"], {o["name"]: o["id"] for o in f["options"]}

    ms_id, ms = new_field("Phase", [(n, "GRAY", d) for n, d in MILESTONES])
    area_id, area = new_field("Area", [(n, c, "") for n, c in AREAS])

    def set_fields(item, m, a, s):
        for field, option in [(status_id, status[s]), (ms_id, ms[MILESTONES[m][0]]), (area_id, area[a])]:
            gql_json("mutation($p:ID!,$i:ID!,$f:ID!,$o:String!){updateProjectV2ItemFieldValue(input:{projectId:$p,itemId:$i,fieldId:$f,value:{singleSelectOptionId:$o}}){projectV2Item{id}}}",
                     {"p": pid, "i": item, "f": field, "o": option})

    for number, (m, a, s) in PRS.items():
        pr = gql("query{repository(owner:\"%s\",name:\"%s\"){pullRequest(number:%d){id}}}" % (ORG, REPO, number))
        item = gql_json("mutation($p:ID!,$c:ID!){addProjectV2ItemById(input:{projectId:$p,contentId:$c}){item{id}}}",
                        {"p": pid, "c": pr["repository"]["pullRequest"]["id"]})["addProjectV2ItemById"]["item"]["id"]
        set_fields(item, m, a, s)

    for title, m, a, s, body in DRAFTS:
        item = gql_json("mutation($p:ID!,$t:String!,$b:String){addProjectV2DraftIssue(input:{projectId:$p,title:$t,body:$b}){projectItem{id}}}",
                        {"p": pid, "t": title, "b": body})["addProjectV2DraftIssue"]["projectItem"]["id"]
        set_fields(item, m, a, s)

    print(project["url"])


if __name__ == "__main__":
    main()
