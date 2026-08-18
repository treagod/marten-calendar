# Changelog

## Unreleased

## 0.3.0 (2026-08-18)

- Added support for reading `year`/`month` from the request query params when no explicit `year`/`month` kwarg is given; invalid or partial values are ignored.
- Added strict validation of calendar tag arguments: unknown kwargs, non-integer or out-of-range `year`/`month`, unsupported `week_start` / `fill_adjacent` values, and a `min` after `max` now raise `Marten::Template::Errors::UnsupportedValue`.
- Added `1`/`0`, `yes`/`no`, `on`/`off`, `y`/`n`, `t`/`f` as accepted `fill_adjacent` values; unrecognized values now raise instead of silently resolving to `false`.
- Changed calendar navigation to omit the previous/next link when the adjacent month contains no day within the `min`/`max` bounds.
- Fixed calendar dates to respect `Marten.settings.time_zone`, including RFC 3339 inputs with an offset.

## 0.2.1 (2026-03-12)

- Fixed default calendar month selection to respect `min`/`max` bounds when no explicit `year` or `month` is provided.

## 0.2.0 (2026-03-06)

- Added month calendar event support via `{% calendar events: meetings %}`.
- Added per-cell event exposure through `calendar_cell.events`.
- Added support for single-day and multi-day events using `start_time` / optional `end_time`.
- Added validation errors for missing or invalid event date data.

## 0.1.0 (2026-02-02)

Initial release of MartenCalendar
