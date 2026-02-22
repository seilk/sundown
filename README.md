# Sundown

Sundown is an open-source macOS menubar app for healthier work pacing.

It helps people who tend to work without clear limits by making overwork visible without aggressive interruption.

## Core idea

- Show remaining time in the menubar during the workday.
- After limit is exceeded, show over-time in red and keep counting.
- Keep optional notifications available, but not required.
- Provide a simple daily ritual view with Work/Break/Idle split.

## Stack

- macOS app: SwiftUI + AppKit
- Local data: UserDefaults + JSON
- License: MIT

## Product status

This repository currently contains planning docs for MVP setup.

## Development mode

- Implementation follows strict TDD.
- Features are shipped one step at a time.
- After each feature increment, a user checkpoint is required before the next step.
- Prototype testing is expected during development, not only after MVP completion.

## OpenCode skills setup

- External skill packs are installed in `./.skills/`.
- Workspace config is in `opencode.json`.
- Configured skill paths:
  - `./.skills/agent-skills/skills`
  - `./.skills/anthropic-skills/skills`
  - `./.claude/skills`
- Restart OpenCode session to reload skill sources.

See:

- `PRD.md`
- `ARCHITECTURE.md`
- `RULES.md`
- `DEFAULTS.md`
- `UX_FLOW.md`
- `ROADMAP.md`
- `RELEASE.md`
- `TDD_WORKFLOW.md`
- `PROTOTYPE_TESTING.md`
