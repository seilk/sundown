# Architecture (MVP)

## Runtime layers

- `App Layer` (SwiftUI + AppKit): menubar UI, settings, ritual view.
- `Domain Layer`: session state, limit calculations, day window logic.
- `Data Layer`: UserDefaults-backed JSON persistence.

## Main modules

- `TimeEngine`
  - Computes elapsed, remaining, and over-time values.
  - Applies day reset boundary.
- `ActivityClassifier`
  - Categorizes time into Work/Break/Idle.
  - Idle is based on no keyboard/mouse input threshold.
- `NotificationService`
  - Optional local notifications.
  - Triggers on over-limit rules.
- `StorageService`
  - Saves and loads settings + day records via UserDefaults JSON.

## Data model (conceptual)

- `UserSettings`
  - `dailyLimitMinutes`
  - `dayResetTime` (local time)
  - `idleThresholdMinutes`
  - `notificationsEnabled`
  - `overLimitReminderMinutes`
- `DayRecord`
  - `dayId`
  - `workMinutes`
  - `breakMinutes`
  - `idleMinutes`
  - `limitMinutes`
  - `overMinutes`

## Design constraints

- Local-first. No network dependency in MVP.
- Keep state transitions deterministic and testable.
- Prefer simple JSON schema with version field for migration.
