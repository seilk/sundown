# Product Rules (MVP)

## Menubar display

- Under limit: show remaining time, example `2:18 left`.
- Over limit: show over-time, example `+0:37`.
- Over limit state must use red text color.

## Intervention strategy

- Primary intervention: passive visual feedback in menubar.
- Optional intervention: local notifications.

## Notifications (optional)

- Trigger once immediately when limit is exceeded.
- Then trigger every 30 minutes while still over limit.
- User can disable notifications entirely.

## Activity classification

- Initial categories: Work, Break, Idle.
- Idle detection: no keyboard/mouse input for 5 minutes.

## Goal behavior

- Goal mode is optional for users.
- App must still work in visual pacing mode.
