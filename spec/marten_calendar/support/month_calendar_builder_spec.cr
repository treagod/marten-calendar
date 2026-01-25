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
end
