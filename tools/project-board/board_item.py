"""Moves a card on the Usra roadmap board, adding a PR first if needed.

    python3 board_item.py '#5' --status 'In review' --phase 'M1 Core records' --area App
    python3 board_item.py 'Doctors directory' --status 'In progress'

The first argument is a PR number ('#5') or part of a card title.
"""
import argparse
import json
import subprocess
import sys

ORG, NUMBER, REPO = "Opsedia-ai", "2", "usra"


def gh(*args):
    out = subprocess.run(["gh", *args], capture_output=True, text=True)
    if out.returncode:
        sys.exit(out.stderr.strip())
    return out.stdout


def main():
    p = argparse.ArgumentParser()
    p.add_argument("target")
    p.add_argument("--status")
    p.add_argument("--phase")
    p.add_argument("--area")
    a = p.parse_args()

    project_id = json.loads(gh("project", "view", NUMBER, "--owner", ORG, "--format", "json"))["id"]
    fields = {f["name"]: f for f in json.loads(
        gh("project", "field-list", NUMBER, "--owner", ORG, "--format", "json"))["fields"]}
    items = json.loads(gh("project", "item-list", NUMBER, "--owner", ORG, "--limit", "500",
                          "--format", "json"))["items"]

    if a.target.startswith("#"):
        n = int(a.target[1:])
        match = [i for i in items if i["content"].get("number") == n
                 and i["content"].get("repository", "").endswith(REPO)]
        if not match:
            url = f"https://github.com/{ORG}/{REPO}/pull/{n}"
            match = [json.loads(gh("project", "item-add", NUMBER, "--owner", ORG, "--url", url,
                                   "--format", "json"))]
    else:
        match = [i for i in items if i["title"].lower() == a.target.lower()]
        match = match or [i for i in items if a.target.lower() in i["title"].lower()]
    if len(match) != 1:
        sys.exit(f"{len(match)} cards match {a.target!r}: {[i['title'] for i in match]}")
    item = match[0]

    for name, value in [("Status", a.status), ("Phase", a.phase), ("Area", a.area)]:
        if value is None:
            continue
        field = fields[name]
        option = next((o["id"] for o in field["options"] if o["name"] == value), None)
        if option is None:
            sys.exit(f"{name} has no option {value!r}")
        gh("project", "item-edit", "--project-id", project_id, "--id", item["id"],
           "--field-id", field["id"], "--single-select-option-id", option)
    print(f"{item.get('title') or a.target}: updated")


if __name__ == "__main__":
    main()
