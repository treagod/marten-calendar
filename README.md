# Marten Calendar

[![GitHub Release](https://img.shields.io/github/v/release/treagod/marten-calendar?style=flat)](https://github.com/treagod/marten-calendar/releases)
[![Marten Calendar Specs](https://github.com/treagod/marten-calendar/actions/workflows/specs.yml/badge.svg)](https://github.com/treagod/marten-calendar/actions/workflows/specs.yml)
[![QA](https://github.com/treagod/marten-calendar/actions/workflows/qa.yml/badge.svg)](https://github.com/treagod/marten-calendar/actions/workflows/qa.yml)

Marten Calendar is a Marten extension that provides the foundation for calendar- and scheduling-related features.

> **Note**: This shard is currently being bootstrapped. Documentation and usage examples will continue to evolve as the implementation is built out.

## Checklist

- [x] Current calendar rendering functionality
- [ ] Month calendar event support

## Installation

Add the following dependency to your project's `shard.yml`:

```yaml
dependencies:
  marten_calendar:
    github: treagod/marten-calendar
```

Then run `shards install`.

Require the shard from your project's `src/project.cr` file:

```crystal
require "marten_calendar"
```

Finally register the application in your Marten configuration:

```crystal
config.installed_apps = [
  # …
  MartenCalendar::App
]
```

## Usage

### Template tag

This shard registers a `calendar` template tag. It renders a month grid that handles navigation helpers, optional min/max date constraints, and localized parsing for strings. By default the tag renders the templates that ship in `MartenCalendar::App`, but you can point it to custom templates via settings:

```crystal
Marten.settings.calendar.template_path = "calendar/month_calendar.html"
Marten.settings.calendar.cell_template_path = "calendar/month_calendar_cell.html"
```

In a template you can invoke it as follows:

```django
{% calendar year: calendar_year, month: calendar_month, fill_adjacent: true %}
```

Supported kwargs include `year`, `month`, `week_start`, `fill_adjacent`, `min`, `max`, `default`, `template`, and `cell_template`.

### Rendering from a handler

The shard is focused on the template tag only. If you want to preview the calendar while developing or use it inside a page, wire a handler in your project and feed the context the tag expects:

```crystal
class CalendarPage < Marten::Handlers::Template
  template_name "marten_calendar.html"

  before_render :set_calendar_context

  private def set_calendar_context
    now = Time.local
    context[:calendar_year] = now.year
    context[:calendar_month] = now.month
  end
end
```
