require "./spec_helper"

describe MartenCalendar do
  describe MartenCalendar::Settings do
    it "exposes default template paths" do
      settings = MartenCalendar::Settings.new

      settings.template_path.should eq "marten_calendar/month_calendar.html"
      settings.cell_template_path.should eq "marten_calendar/month_calendar_cell.html"
    end

    it "allows overriding template paths through Marten settings" do
      snapshot = MartenCalendar::Settings.new

      begin
        Marten.settings.calendar.template_path = "spec_calendar/custom_month_calendar.html"
        Marten.settings.calendar.cell_template_path = "spec_calendar/custom_calendar_cell.html"

        with_calendar_templates do
          rendered = render_calendar_tag
          rendered.should contain "Custom Month Template"
          rendered.should contain %(<span class="custom-cell day">)
        end
      ensure
        Marten.settings.calendar.template_path = snapshot.template_path
        Marten.settings.calendar.cell_template_path = snapshot.cell_template_path
      end
    end
  end

  describe MartenCalendar::App do
    it "registers the calendar template tag" do
      MartenCalendar::App.new.setup

      Marten::Template::Tag.get("calendar").should eq MartenCalendar::Tags::CalendarTag
    end

    it "exposes a templates loader pointing to the shard templates directory" do
      loader = MartenCalendar::App.new.templates_loader.not_nil!

      template = loader.get_template("marten_calendar/month_calendar.html")
      template.should be_a(Marten::Template::Template)
    end
  end

  describe MartenCalendar::Tags::CalendarTag do
    it "renders the default calendar template with the expected structure" do
      with_calendar_templates do
        rendered = render_calendar_tag

        rendered.should contain %(<section class="marten-calendar" aria-label="Calendar 1/2024">)
        rendered.should contain %(<span class="calendar-title">)
        rendered.should contain %(<th scope="col">Mon</th>)
        rendered.should contain %(<th scope="col">Sun</th>)
        rendered.should contain %(<time datetime="2024-01-01">1</time>)
        rendered.should contain %(<table class="calendar-table" role="grid">)
      end
    end

    it "fills days from adjacent months when requested" do
      with_calendar_templates do
        rendered = render_calendar_tag(
          "{% calendar year: calendar_year, month: calendar_month, fill_adjacent: true %}",
          calendar_context(year: 2024, month: 2)
        )

        rendered.should contain "adjacent-prev-month"
        rendered.should contain "adjacent-next-month"
      end
    end

    it "uses blank placeholders when adjacent filling is disabled" do
      with_calendar_templates do
        rendered = render_calendar_tag(
          "{% calendar year: calendar_year, month: calendar_month, fill_adjacent: false %}",
          calendar_context(year: 2024, month: 6)
        )

        rendered.should match(/class="\s*blank/)
      end
    end

    it "supports switching the week start to Sunday" do
      with_calendar_templates do
        rendered = render_calendar_tag(
          "{% calendar year: calendar_year, month: calendar_month, week_start: 'sunday' %}"
        )

        rendered.should match(/<th scope="col">Sun<\/th>\s*<th scope="col">Mon/m)
      end
    end

    it "applies min, max, and default restrictions" do
      with_calendar_templates do
        source = String.build do |str|
          str << "{% calendar year: calendar_year, month: calendar_month, min: '2024-02-10',"
          str << " max: '2024-02-20', default: '02/15/2024' %}"
        end
        rendered = render_calendar_tag(
          source,
          calendar_context(year: 2024, month: 2)
        )

        rendered.should match(/aria-disabled="true"[^<]*<time datetime="2024-02-09">9<\/time>/m)
        rendered.should match(/aria-disabled="true"[^<]*<time datetime="2024-02-21">21<\/time>/m)
        rendered.should match(/aria-selected="true"[^<]*<time datetime="2024-02-15">15<\/time>/m)
      end
    end

    it "allows overriding templates via tag kwargs" do
      with_calendar_templates do
        source = String.build do |str|
          str << "{% calendar year: calendar_year, month: calendar_month,"
          str << " template: 'spec_calendar/custom_month_calendar.html',"
          str << " cell_template: 'spec_calendar/custom_calendar_cell.html' %}"
        end
        rendered = render_calendar_tag(source)

        rendered.should contain "Custom Month Template"
        rendered.should contain %(<span class="custom-cell day">)
      end
    end

    it "builds navigation links when a request is provided" do
      with_calendar_templates(include_request_context: true) do
        rendered = render_calendar_tag(
          "{% calendar year: calendar_year, month: calendar_month, fill_adjacent: true %}",
          calendar_context(year: 2024, month: 1),
          "/calendar?month=1&year=2024"
        )

        rendered.should match(/href="\/calendar\?(month=2&amp;year=2024|year=2024&amp;month=2)"/)
        rendered.should match(/href="\/calendar\?(month=12&amp;year=2023|year=2023&amp;month=12)"/)
      end
    end
  end
end

private DEFAULT_TAG_SOURCE = "{% calendar year: calendar_year, month: calendar_month, fill_adjacent: true %}"

private def render_calendar_tag(
  source : String = DEFAULT_TAG_SOURCE,
  context_hash = calendar_context,
  request_path : String? = nil,
)
  template = Marten::Template::Template.new(source)

  if request_path
    context = Marten::Template::Context.from(context_hash, build_http_request(request_path))
    template.render(context)
  else
    template.render(Marten::Template::Context.from(context_hash))
  end
end

private def calendar_context(year : Int32 = 2024, month : Int32 = 1)
  {
    "calendar_year"  => year,
    "calendar_month" => month,
  }
end
