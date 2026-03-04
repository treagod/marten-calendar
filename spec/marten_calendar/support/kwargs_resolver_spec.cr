require "../spec_helper"

describe MartenCalendar::Tags::Support::KwargsResolver do
  describe "#resolve" do
    it "returns defaults when no kwargs are provided" do
      Timecop.freeze(Time.local(2024, 5, 10)) do
        resolver = MartenCalendar::Tags::Support::KwargsResolver.new(
          {} of String => Marten::Template::FilterExpression,
          Marten::Template::Context.from({} of String => Int32)
        )

        config = resolver.resolve

        config.year.should eq 2024
        config.month.should eq 5
        config.monday_start?.should be_true
        config.fill_adjacent?.should be_false
        config.template_path.should eq "marten_calendar/month_calendar.html"
        config.cell_template_path.should eq "marten_calendar/month_calendar_cell.html"
        config.events.should be_empty
      end
    end

    it "parses explicit kwargs and date constraints" do
      context = Marten::Template::Context.from({} of String => Int32)
      kwargs = {
        "year"          => Marten::Template::FilterExpression.new("2026"),
        "month"         => Marten::Template::FilterExpression.new("2"),
        "week_start"    => Marten::Template::FilterExpression.new("'sunday'"),
        "fill_adjacent" => Marten::Template::FilterExpression.new("true"),
        "min"           => Marten::Template::FilterExpression.new("'2026-02-10'"),
        "max"           => Marten::Template::FilterExpression.new("'2026-02-20'"),
        "default"       => Marten::Template::FilterExpression.new("'2026-02-15'"),
        "template"      => Marten::Template::FilterExpression.new("'custom/month.html'"),
        "cell_template" => Marten::Template::FilterExpression.new("'custom/cell.html'"),
      } of String => Marten::Template::FilterExpression

      resolver = MartenCalendar::Tags::Support::KwargsResolver.new(kwargs, context)
      config = resolver.resolve

      config.year.should eq 2026
      config.month.should eq 2
      config.monday_start?.should be_false
      config.fill_adjacent?.should be_true
      config.min_date.should eq Time.utc(2026, 2, 10)
      config.max_date.should eq Time.utc(2026, 2, 20)
      config.default_date.should eq Time.utc(2026, 2, 15)
      config.template_path.should eq "custom/month.html"
      config.cell_template_path.should eq "custom/cell.html"
    end

    it "accepts date-time strings by parsing their ISO date prefix" do
      context = Marten::Template::Context.from({} of String => Int32)
      kwargs = {
        "min" => Marten::Template::FilterExpression.new("'2026-02-10T23:59:59Z'"),
      } of String => Marten::Template::FilterExpression

      resolver = MartenCalendar::Tags::Support::KwargsResolver.new(kwargs, context)
      config = resolver.resolve

      config.min_date.should eq Time.utc(2026, 2, 10)
    end

    it "raises when date inputs cannot be parsed" do
      context = Marten::Template::Context.from({} of String => Int32)
      kwargs = {
        "min" => Marten::Template::FilterExpression.new("'invalid-date'"),
      } of String => Marten::Template::FilterExpression

      resolver = MartenCalendar::Tags::Support::KwargsResolver.new(kwargs, context)

      expect_raises(Marten::Template::Errors::UnsupportedValue) do
        resolver.resolve
      end
    end

    it "honors input formats from Marten settings" do
      context = Marten::Template::Context.from({} of String => Int32)
      kwargs = {
        "min" => Marten::Template::FilterExpression.new("'20.11.2025'"),
      } of String => Marten::Template::FilterExpression

      snapshot = Marten.settings.date_input_formats.dup
      begin
        Marten.settings.date_input_formats = snapshot + ["%d.%m.%Y"]

        resolver = MartenCalendar::Tags::Support::KwargsResolver.new(kwargs, context)
        config = resolver.resolve

        config.min_date.should eq Time.utc(2025, 11, 20)
      ensure
        Marten.settings.date_input_formats = snapshot
      end
    end

    it "honors localized date input formats before settings fallbacks" do
      context = Marten::Template::Context.from({} of String => Int32)
      kwargs = {
        "min" => Marten::Template::FilterExpression.new("'11/20/2025'"),
      } of String => Marten::Template::FilterExpression

      snapshot = Marten.settings.date_input_formats.dup
      begin
        Marten.settings.date_input_formats = ["%d.%m.%Y"]

        resolver = MartenCalendar::Tags::Support::KwargsResolver.new(kwargs, context)
        config = resolver.resolve

        config.min_date.should eq Time.utc(2025, 11, 20)
      ensure
        Marten.settings.date_input_formats = snapshot
      end
    end

    it "normalizes localized parsed dates to UTC day boundaries" do
      context = Marten::Template::Context.from({} of String => Int32)
      kwargs = {
        "default" => Marten::Template::FilterExpression.new("'11/20/2025'"),
      } of String => Marten::Template::FilterExpression

      formats_snapshot = Marten.settings.date_input_formats.dup
      timezone_snapshot = Marten.settings.time_zone
      begin
        Marten.settings.time_zone = Time::Location.load("Europe/Berlin")
        Marten.settings.date_input_formats = ["%d.%m.%Y"] # ensure localized format is used

        resolver = MartenCalendar::Tags::Support::KwargsResolver.new(kwargs, context)
        config = resolver.resolve

        config.default_date.should eq Time.utc(2025, 11, 20)
      ensure
        Marten.settings.date_input_formats = formats_snapshot
        Marten.settings.time_zone = timezone_snapshot
      end
    end

    it "ignores nil values coming from the template context" do
      context = Marten::Template::Context.from({"maybe_max" => nil})
      kwargs = {
        "max" => Marten::Template::FilterExpression.new("maybe_max"),
      } of String => Marten::Template::FilterExpression

      resolver = MartenCalendar::Tags::Support::KwargsResolver.new(kwargs, context)
      config = resolver.resolve

      config.max_date.should be_nil
    end

    it "resolves events from iterable context values" do
      context = Marten::Template::Context.from({
        "meetings" => ["Planning", "Demo"],
      })
      kwargs = {
        "events" => Marten::Template::FilterExpression.new("meetings"),
      } of String => Marten::Template::FilterExpression

      resolver = MartenCalendar::Tags::Support::KwargsResolver.new(kwargs, context)
      config = resolver.resolve

      config.events.map(&.raw).should eq(["Planning", "Demo"])
    end

    it "raises when events kwarg is not iterable" do
      context = Marten::Template::Context.from({"meetings" => 42})
      kwargs = {
        "events" => Marten::Template::FilterExpression.new("meetings"),
      } of String => Marten::Template::FilterExpression

      resolver = MartenCalendar::Tags::Support::KwargsResolver.new(kwargs, context)

      expect_raises(Marten::Template::Errors::UnsupportedValue) do
        resolver.resolve
      end
    end
  end
end
