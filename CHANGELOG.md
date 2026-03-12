# Changelog

## Unreleased

- Fixed default calendar month selection to respect `min`/`max` bounds when no explicit `year` or `month` is provided.

## 0.2.0 (2026-03-06)

- Added month calendar event support via `{% calendar events: meetings %}`.
- Added per-cell event exposure through `calendar_cell.events`.
- Added support for single-day and multi-day events using `start_time` / optional `end_time`.
- Added validation errors for missing or invalid event date data.

## 0.1.0 (2026-02-02)

Initial release of MartenCalendar
