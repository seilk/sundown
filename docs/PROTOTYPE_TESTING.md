# Prototype Testing Guide

## Why test prototypes early

Sundown is behavior-heavy UX. Small interaction details matter more than raw feature count.

## Fast local prototype path

1. Run app from Xcode in Debug.
2. Keep menubar visible while doing real work.
3. Validate under-limit and over-limit transitions in normal usage.
4. Validate idle transitions by intentionally stopping input.

## Dogfooding checklist (daily)

- Onboarding blocks usage until limit and reset time are set.
- Menubar shows remaining time under limit.
- Menubar shows red over-time after limit.
- Optional notifications behave as configured.
- Work/Break/Idle pie chart feels understandable at a glance.

## Simulating long sessions faster

- Add debug-only time acceleration controls in future implementation.
- Add debug action to force over-limit state.
- Add debug action to simulate idle threshold crossing.

## Feedback capture format

For each prototype run, record:

- Date and scenario
- What felt clear
- What felt confusing
- What should change next
