require "../spec_helper"

describe MartenCalendar::Tags::CalendarTag do
  it "returns nil navigation paths when no request context is present" do
    with_calendar_templates do
      rendered = render_calendar_tag_without_request("{% calendar %}")

      rendered.should_not contain %(href=")
    end
  end

  it "returns nil navigation paths when the request wrapper is invalid" do
    with_calendar_templates do
      context = Marten::Template::Context.from({
        "calendar_year"  => 2024,
        "calendar_month" => 1,
      })
      context[:request] = Marten::Template::Value.from("not-a-request")

      rendered = render_calendar_tag_with_context(context: context)

      rendered.should_not contain %(href=")
    end
  end

  it "renders the month from the request query params and links to its neighbours" do
    with_calendar_templates do
      context = Marten::Template::Context.from({} of String => Int32)
      context[:request] = Marten::Template::Value.from(build_http_request("/calendar?year=2026&month=8"))

      rendered = render_calendar_tag_with_context(context: context)

      rendered.should contain "2026"
      rendered.should contain "August"
      rendered.should contain "year=2026&amp;month=9"
      rendered.should contain "year=2026&amp;month=7"
    end
  end

  it "marks today based on the configured time zone" do
    snapshot = Marten.settings.time_zone
    begin
      Marten.settings.time_zone = Time::Location.load("Europe/Berlin")

      Timecop.freeze(Time.utc(2026, 7, 18, 23, 30)) do
        with_calendar_templates do
          rendered = render_calendar_tag_without_request("{% calendar year: 2026, month: 7 %}")

          rendered.should match /aria-current="date"[\s\S]*?datetime="2026-07-19"/
        end
      end
    ensure
      Marten.settings.time_zone = snapshot
    end
  end

  it "keeps both navigation links when no bounds are given" do
    with_calendar_templates do
      rendered = render_calendar_with_request("{% calendar year: 2026, month: 8 %}")

      rendered.should contain %(class="nav-prev")
      rendered.should contain %(class="nav-next")
    end
  end

  it "hides the previous link when the previous month is entirely before min" do
    with_calendar_templates do
      rendered = render_calendar_with_request(%({% calendar year: 2026, month: 8, min: "2026-08-01" %}))

      rendered.should_not contain %(class="nav-prev")
      rendered.should contain %(class="nav-next")
    end
  end

  it "hides the next link when the next month is entirely after max" do
    with_calendar_templates do
      rendered = render_calendar_with_request(%({% calendar year: 2026, month: 8, max: "2026-08-31" %}))

      rendered.should contain %(class="nav-prev")
      rendered.should_not contain %(class="nav-next")
    end
  end

  it "keeps the previous link when a single day of the previous month is selectable" do
    with_calendar_templates do
      rendered = render_calendar_with_request(%({% calendar year: 2026, month: 8, min: "2026-07-31" %}))

      rendered.should contain %(class="nav-prev")
    end
  end

  it "keeps the next link when a single day of the next month is selectable" do
    with_calendar_templates do
      rendered = render_calendar_with_request(%({% calendar year: 2026, month: 7, max: "2026-08-01" %}))

      rendered.should contain %(class="nav-next")
    end
  end

  it "handles the year boundary for min" do
    with_calendar_templates do
      rendered = render_calendar_with_request(%({% calendar year: 2026, month: 1, min: "2025-12-31" %}))
      rendered.should contain %(class="nav-prev")

      rendered = render_calendar_with_request(%({% calendar year: 2026, month: 1, min: "2026-01-01" %}))
      rendered.should_not contain %(class="nav-prev")
    end
  end

  it "handles the year boundary for max" do
    with_calendar_templates do
      rendered = render_calendar_with_request(%({% calendar year: 2026, month: 12, max: "2027-01-01" %}))
      rendered.should contain %(class="nav-next")

      rendered = render_calendar_with_request(%({% calendar year: 2026, month: 12, max: "2026-12-31" %}))
      rendered.should_not contain %(class="nav-next")
    end
  end
end

private def render_calendar_with_request(source : String)
  context = Marten::Template::Context.from({} of String => Int32)
  context[:request] = Marten::Template::Value.from(build_http_request("/calendar"))

  render_calendar_tag_with_context(context: context, source: source)
end

private def render_calendar_tag_without_request(source)
  template = Marten::Template::Template.new(source)
  template.render(Marten::Template::Context.from({
    "calendar_year"  => 2024,
    "calendar_month" => 1,
  }))
end

private def render_calendar_tag_with_context(context : Marten::Template::Context, source = "{% calendar %}")
  template = Marten::Template::Template.new(source)
  template.render(context)
end
