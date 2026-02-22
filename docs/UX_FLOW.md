# UX Flow (MVP)

## First run

1. Welcome screen explains purpose: sustainable pacing, not forced blocking.
2. User selects daily limit from 6h/8h/10h/Custom.
3. User sets day reset time.
4. User optionally enables over-limit notifications.
5. App enters menubar running state.

## Menubar state flow

- `Normal`: show remaining time.
- `Over-limit`: switch to red and show over-time.
- Clicking menubar opens quick panel with:
  - current status
  - today's Work/Break/Idle pie chart
  - shortcut to settings

## Settings flow

- Change limit, reset time, idle threshold.
- Enable/disable notifications.
- Adjust notification reminder interval.

## Daily ritual view

- Display same-day distribution in pie chart.
- Show totals for Work, Break, Idle.
- Keep chart readable at a glance.
