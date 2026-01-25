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
