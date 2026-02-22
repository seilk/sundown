# TDD Workflow

## Goal

Build Sundown with short, verifiable feature increments where tests define behavior first.

## Default loop (for every feature)

1. Define one thin feature slice.
2. Write failing tests first.
3. Implement minimum code to pass tests.
4. Refactor with tests still green.
5. Run full relevant checks.
6. Run a prototype build and collect UX feedback.
7. Pause for user checkpoint before next slice.

## Test layers

- Unit tests: time math, reset boundary, idle detection transitions.
- Integration tests: settings persistence and state propagation.
- UI tests (incremental): menubar display state and onboarding requirements.

## Definition of done per slice

- New behavior is covered by tests.
- Existing tests still pass.
- No type or analyzer errors.
- Prototype run confirms expected UX.
- User feedback is captured before continuing.

## User checkpoint template

After each feature increment, report:

- What changed
- What test proves it
- How to try it in prototype
- One direct question: "Does this feel right?"
