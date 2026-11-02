# Project board scripts

Builds the [Usra roadmap](https://github.com/orgs/Opsedia-ai/projects/2) board.
Needs `gh` with the `project` scope: `gh auth refresh -h github.com -s project`.

- `create_board.py` creates a **new** board with the Status, Phase and Area fields,
  PRs #1–#3, the roadmap cards and founder tasks. Running it again makes a second board.
- `create_views.sh` adds the By phase, My tasks and Roadmap table views to board 2.
  Field IDs are hard-coded for that board (`gh api orgs/Opsedia-ai/projectsV2/2/fields`).

The Board view (columns by Status) was made with:
`gh api -X POST orgs/Opsedia-ai/projectsV2/2/views -f name=Board -f layout=board`
