require "../spec_helper"

describe MartenCalendar::Tags::Support::MonthCalendarBuilder do
  it "builds a month calendar with adjacency and selection metadata" do
    config = MartenCalendar::Tags::Support::CalendarConfig.new(
      2024,
      2,
      true,
      true,
      Time.utc(2024, 2, 10),
      Time.utc(2024, 2, 20),
      Time.utc(2024, 2, 15),
      "marten_calendar/month_calendar.html",
      "marten_calendar/month_calendar_cell.html"
    )

    builder = MartenCalendar::Tags::Support::MonthCalendarBuilder.new(
      config,
      Time.utc(2024, 2, 15)
    )

    calendar = builder.build

    calendar.month.should eq 2
    calendar.year.should eq 2024
    calendar.weekday_names.first.should eq "Mon"
    calendar.prev_month.should eq 1
    calendar.prev_year.should eq 2024
    calendar.next_month.should eq 3
    calendar.next_year.should eq 2024

    first_cell = calendar.calendar_cells.first.first
    first_cell.day.should eq 29
    first_cell.adjacent_prev_month?.should be_true

    february_cells = calendar.calendar_cells.flatten.select { |cell| cell.iso.try &.starts_with?("2024-02") }
    february_cells.size.should eq 29 # leap year February includes 29 days

    selected_cell = calendar.calendar_cells.flatten.find { |cell| cell.iso == "2024-02-15" }
    selected_cell.not_nil!.selected?.should be_true
    selected_cell.not_nil!.today?.should be_true
    selected_cell.not_nil!.disabled?.should be_false

    disabled_before = calendar.calendar_cells.flatten.find { |cell| cell.iso == "2024-02-09" }
    disabled_before.not_nil!.disabled?.should be_true
    disabled_after = calendar.calendar_cells.flatten.find { |cell| cell.iso == "2024-02-21" }
    disabled_after.not_nil!.disabled?.should be_true
  end

  it "produces blank placeholders when fill_adjacent is false" do
    config = MartenCalendar::Tags::Support::CalendarConfig.new(
      2024,
      6,
      true,
      false,
      nil,
      nil,
      nil,
      "marten_calendar/month_calendar.html",
      "marten_calendar/month_calendar_cell.html"
    )

    builder = MartenCalendar::Tags::Support::MonthCalendarBuilder.new(
      config,
      Time.utc(2024, 6, 1)
    )

    calendar = builder.build

    blank_cells = calendar.calendar_cells.flatten.select(&.blank?)
    blank_cells.should_not be_empty
    blank_cells.all?(&.adjacent_prev_month?.!).should be_true
    blank_cells.all?(&.adjacent_next_month?.!).should be_true
  end

  it "does not mark defaults outside min/max as selected" do
    config = MartenCalendar::Tags::Support::CalendarConfig.new(
      2024,
      3,
      true,
      true,
      Time.utc(2024, 3, 5),
      Time.utc(2024, 3, 10),
      Time.utc(2024, 3, 3), # outside min
      "marten_calendar/month_calendar.html",
      "marten_calendar/month_calendar_cell.html"
    )

    builder = MartenCalendar::Tags::Support::MonthCalendarBuilder.new(
      config,
      Time.utc(2024, 3, 15)
    )

    calendar = builder.build

    selected_cells = calendar.calendar_cells.flatten.select(&.selected?)
    selected_cells.should be_empty
  end

  it "attaches single-day events to matching dates only" do
    event = CalendarSpecEvent.new("Planning", Time.utc(2024, 2, 15))
    config = MartenCalendar::Tags::Support::CalendarConfig.new(
      2024,
      2,
      true,
      true,
      nil,
      nil,
      nil,
      "marten_calendar/month_calendar.html",
      "marten_calendar/month_calendar_cell.html",
      [Marten::Template::Value.from(event)]
    )

    calendar = MartenCalendar::Tags::Support::MonthCalendarBuilder.new(
      config,
      Time.utc(2024, 2, 1)
    ).build

    cell_for_iso(calendar, "2024-02-14").events.should be_empty
    cell_for_iso(calendar, "2024-02-15").events.size.should eq 1
    cell_for_iso(calendar, "2024-02-16").events.should be_empty
  end

  it "maps multi-day events across the full inclusive span" do
    event = CalendarSpecEvent.new(
      "Conference",
      Time.utc(2024, 2, 10),
      Time.utc(2024, 2, 12)
    )
    config = MartenCalendar::Tags::Support::CalendarConfig.new(
      2024,
      2,
      true,
      true,
      nil,
      nil,
      nil,
      "marten_calendar/month_calendar.html",
      "marten_calendar/month_calendar_cell.html",
      [Marten::Template::Value.from(event)]
    )

    calendar = MartenCalendar::Tags::Support::MonthCalendarBuilder.new(
      config,
      Time.utc(2024, 2, 1)
    ).build

    cell_for_iso(calendar, "2024-02-10").events.size.should eq 1
    cell_for_iso(calendar, "2024-02-11").events.size.should eq 1
    cell_for_iso(calendar, "2024-02-12").events.size.should eq 1
    cell_for_iso(calendar, "2024-02-13").events.should be_empty
  end

  it "clips multi-day events to the visible date range" do
    event = CalendarSpecEvent.new(
      "Long trip",
      Time.utc(2024, 1, 28),
      Time.utc(2024, 3, 3)
    )
    config = MartenCalendar::Tags::Support::CalendarConfig.new(
      2024,
      2,
      true,
      false,
      nil,
      nil,
      nil,
      "marten_calendar/month_calendar.html",
      "marten_calendar/month_calendar_cell.html",
      [Marten::Template::Value.from(event)]
    )

    calendar = MartenCalendar::Tags::Support::MonthCalendarBuilder.new(
      config,
      Time.utc(2024, 2, 1)
    ).build

    cell_for_iso(calendar, "2024-02-01").events.size.should eq 1
    cell_for_iso(calendar, "2024-02-29").events.size.should eq 1
    calendar.calendar_cells.flatten.select(&.blank?).all?(&.events.empty?).should be_true
  end

  it "raises when an event does not expose start_time" do
    config = MartenCalendar::Tags::Support::CalendarConfig.new(
      2024,
      2,
      true,
      true,
      nil,
      nil,
      nil,
      "marten_calendar/month_calendar.html",
      "marten_calendar/month_calendar_cell.html",
      [Marten::Template::Value.from(CalendarSpecEventWithoutStartTime.new("Broken"))]
    )

    builder = MartenCalendar::Tags::Support::MonthCalendarBuilder.new(
      config,
      Time.utc(2024, 2, 1)
    )

    expect_raises(Marten::Template::Errors::UnsupportedValue) do
      builder.build
    end
  end

  it "raises when start_time cannot be parsed" do
    event = CalendarSpecEvent.new("Broken", "not-a-date")
    config = MartenCalendar::Tags::Support::CalendarConfig.new(
      2024,
      2,
      true,
      true,
      nil,
      nil,
      nil,
      "marten_calendar/month_calendar.html",
      "marten_calendar/month_calendar_cell.html",
      [Marten::Template::Value.from(event)]
    )

    builder = MartenCalendar::Tags::Support::MonthCalendarBuilder.new(
      config,
      Time.utc(2024, 2, 1)
    )

    expect_raises(Marten::Template::Errors::UnsupportedValue) do
      builder.build
    end
  end

  it "raises when end_time cannot be parsed" do
    event = CalendarSpecEvent.new("Broken", Time.utc(2024, 2, 10), "not-a-date")
    config = MartenCalendar::Tags::Support::CalendarConfig.new(
      2024,
      2,
      true,
      true,
      nil,
      nil,
      nil,
      "marten_calendar/month_calendar.html",
      "marten_calendar/month_calendar_cell.html",
      [Marten::Template::Value.from(event)]
    )

    builder = MartenCalendar::Tags::Support::MonthCalendarBuilder.new(
      config,
      Time.utc(2024, 2, 1)
    )

    expect_raises(Marten::Template::Errors::UnsupportedValue) do
      builder.build
    end
  end

  it "raises when end_time is before start_time" do
    event = CalendarSpecEvent.new(
      "Broken range",
      Time.utc(2024, 2, 12),
      Time.utc(2024, 2, 10)
    )
    config = MartenCalendar::Tags::Support::CalendarConfig.new(
      2024,
      2,
      true,
      true,
      nil,
      nil,
      nil,
      "marten_calendar/month_calendar.html",
      "marten_calendar/month_calendar_cell.html",
      [Marten::Template::Value.from(event)]
    )

    builder = MartenCalendar::Tags::Support::MonthCalendarBuilder.new(
      config,
      Time.utc(2024, 2, 1)
    )

    expect_raises(Marten::Template::Errors::UnsupportedValue) do
      builder.build
    end
  end
end

private def cell_for_iso(
  calendar : MartenCalendar::Tags::Support::MonthCalendar,
  iso : String,
) : MartenCalendar::Tags::Support::CalendarCell
  calendar.calendar_cells.flatten.find { |cell| cell.iso == iso }.not_nil!
end
