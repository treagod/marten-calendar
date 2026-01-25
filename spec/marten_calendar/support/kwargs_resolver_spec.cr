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
        config.monday_start.should be_true
        config.fill_adjacent.should be_false
        config.template_path.should eq "marten_calendar/month_calendar.html"
        config.cell_template_path.should eq "marten_calendar/month_calendar_cell.html"
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
      config.monday_start.should be_false
      config.fill_adjacent.should be_true
      config.min_date.should eq Time.utc(2026, 2, 10)
      config.max_date.should eq Time.utc(2026, 2, 20)
      config.default_date.should eq Time.utc(2026, 2, 15)
      config.template_path.should eq "custom/month.html"
      config.cell_template_path.should eq "custom/cell.html"
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

    it "honors localized input formats from I18n" do
      context = Marten::Template::Context.from({} of String => Int32)
      kwargs = {
        "min" => Marten::Template::FilterExpression.new("'20.11.2025'"),
      } of String => Marten::Template::FilterExpression

      I18n.locale = :de
      begin
        resolver = MartenCalendar::Tags::Support::KwargsResolver.new(kwargs, context)
        config = resolver.resolve

        config.min_date.should eq Time.utc(2025, 11, 20)
      ensure
        I18n.locale = :en
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
  end
end
