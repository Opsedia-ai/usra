#!/bin/sh
# Creates the Usra roadmap views (GitHub Projects REST API).
set -e
P=orgs/Opsedia-ai/projectsV2/2/views
mk() { gh api -X POST $P --input - --jq '"\(.name): \(.html_url)"'; }
echo '{"name":"By phase","layout":"board","vertical_group_by":[437465512],"visible_fields":[437465426,437465431,437465539]}' | mk
echo '{"name":"My tasks","layout":"table","filter":"area:\"Founder tasks\" -status:Done","visible_fields":[437465426,437465431,437465512]}' | mk
echo '{"name":"Roadmap table","layout":"table","group_by":[437465512],"visible_fields":[437465426,437465431,437465539]}' | mk
