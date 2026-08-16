require "../spec_helper"

describe MartenCalendar::Tags::Support::DateInputParser do
  describe "#parse" do
    it "shifts time values forward into the configured time zone" do
      with_time_zone("Europe/Berlin") do
        parse(Time.utc(2026, 7, 18, 23, 30)).should eq Time.utc(2026, 7, 19)
      end
    end

    it "shifts time values backward into the configured time zone" do
      with_time_zone("America/New_York") do
        parse(Time.utc(2026, 7, 19, 2, 30)).should eq Time.utc(2026, 7, 18)
      end
    end

    it "never shifts date-only ISO strings" do
      with_time_zone("Europe/Berlin") do
        parse("2026-07-19").should eq Time.utc(2026, 7, 19)
      end

      with_time_zone("America/New_York") do
        parse("2026-07-19").should eq Time.utc(2026, 7, 19)
      end
    end

    it "never shifts strings parsed with the configured input formats" do
      snapshot = Marten.settings.date_input_formats.dup
      begin
        Marten.settings.date_input_formats = ["%d.%m.%Y"]

        with_time_zone("Europe/Berlin") do
          parse("19.07.2026").should eq Time.utc(2026, 7, 19)
        end

        with_time_zone("America/New_York") do
          parse("19.07.2026").should eq Time.utc(2026, 7, 19)
        end
      ensure
        Marten.settings.date_input_formats = snapshot
      end
    end

    it "applies the configured time zone to template values wrapping a time" do
      with_time_zone("Europe/Berlin") do
        value = Marten::Template::Value.from(Time.utc(2026, 7, 18, 23, 30))

        parse(value).should eq Time.utc(2026, 7, 19)
      end
    end

    it "treats ISO date-time strings carrying an offset as timestamps" do
      with_time_zone("Europe/Berlin") do
        parse("2026-07-18T23:30:00Z").should eq parse(Time.utc(2026, 7, 18, 23, 30))
        parse("2026-07-18T23:30:00Z").should eq Time.utc(2026, 7, 19)
      end
    end

    it "keeps the date prefix of ISO date-time strings without an offset" do
      with_time_zone("Europe/Berlin") do
        parse("2026-07-18T23:30:00").should eq Time.utc(2026, 7, 18)
      end
    end
  end
end

private def parse(value)
  MartenCalendar::Tags::Support::DateInputParser.parse(value)
end

private def with_time_zone(name : String, &)
  snapshot = Marten.settings.time_zone
  begin
    Marten.settings.time_zone = Time::Location.load(name)
    yield
  ensure
    Marten.settings.time_zone = snapshot
  end
end
