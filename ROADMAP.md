# Roadmap

## Phase 0: Setup (current)

- Define product scope and rules.
- Create lightweight doc system for build alignment.

## Phase 1: MVP implementation

- Build menubar app shell with SwiftUI + AppKit.
- Implement onboarding (required limit + reset time).
- Implement time engine and over-limit color state.
- Add optional notifications.
- Add Work/Break/Idle tracking and pie chart view.
- Persist settings and day records with UserDefaults + JSON.
- Execute feature slices via TDD (tests first, then minimal implementation).
- Pause after each completed slice for user feedback checkpoint.

## Phase 2: Hardening

- Add tests for time calculations and day reset boundaries.
- Add edge-case handling around sleep/wake and timezone changes.
- Improve chart clarity and accessibility.

## Phase 3: OSS release readiness

- Polish README and contribution docs.
- Add issue templates and PR template.
- Add release checklist and versioning policy.
