module MartenCalendar
  module Tags
    module Support
      class MonthCalendarBuilder
        alias CalendarEvents = Array(Marten::Template::Value)
        alias EventsByISO = Hash(String, CalendarEvents)

        def initialize(
          @config : CalendarConfig,
          @today : Time,
        )
        end

        def build : MonthCalendar
          prev_year, prev_month = prev_month_tuple(@config.year, @config.month)
          next_year, next_month = next_month_tuple(@config.year, @config.month)
          visible_start, visible_end = visible_date_range(
            @config.year,
            @config.month,
            @config.monday_start?,
            @config.fill_adjacent?
          )

          weekday_names = localized_weekday_names(@config.monday_start?)
          events_by_iso = build_events_index(@config.events, visible_start, visible_end)
          calendar_weeks = build_calendar_cells(
            @config.year,
            @config.month,
            @config.monday_start?,
            @config.fill_adjacent?,
            @config.min_date,
            @config.max_date,
            @config.default_date,
            prev_year,
            prev_month,
            next_year,
            next_month,
            events_by_iso
          )

          MonthCalendar.new(
            @config.month,
            month_title(@config.month),
            @config.year,
            weekday_names,
            calendar_weeks,
            prev_year,
            prev_month,
            next_year,
            next_month
          )
        end

        private def build_calendar_cells(
          year : Int32,
          month : Int32,
          monday_start : Bool,
          fill_adjacent : Bool,
          min_date : Time?,
          max_date : Time?,
          default_date : Time?,
          prev_year : Int32,
          prev_month : Int32,
          next_year : Int32,
          next_month : Int32,
          events_by_iso : EventsByISO,
        ) : Array(Array(CalendarCell))
          first_day = Time.utc(year, month, 1)
          days_in_month = Time.days_in_month(year, month)
          first_weekday = monday_start ? (first_day.day_of_week.value - 1) : (first_day.day_of_week.value % 7)
          prev_dim = Time.days_in_month(prev_year, prev_month)

          calendar_cells = Array(CalendarCell).new

          if fill_adjacent && first_weekday > 0
            start_d = prev_dim - first_weekday + 1
            start_d.upto(prev_dim) do |d|
              date = Time.utc(prev_year, prev_month, d)
              calendar_cells << build_calendar_cell(
                date,
                d,
                min_date,
                max_date,
                default_date,
                events_by_iso,
                adjacent_prev_month: true
              )
            end
          else
            first_weekday.times do
              calendar_cells << CalendarCell.new(nil, nil)
            end
          end

          1.upto(days_in_month) do |d|
            date = Time.utc(year, month, d)
            calendar_cells << build_calendar_cell(
              date,
              d,
              min_date,
              max_date,
              default_date,
              events_by_iso
            )
          end

          trailing = (7 - ((first_weekday + days_in_month) % 7)) % 7
          if fill_adjacent && trailing > 0
            1.upto(trailing) do |d|
              date = Time.utc(next_year, next_month, d)
              calendar_cells << build_calendar_cell(
                date,
                d,
                min_date,
                max_date,
                default_date,
                events_by_iso,
                adjacent_next_month: true
              )
            end
          else
            trailing.times do
              calendar_cells << CalendarCell.new(nil, nil)
            end
          end

          calendar_cells.in_slices_of(7)
        end

        private def build_calendar_cell(
          date : Time,
          day : Int32,
          min_date : Time?,
          max_date : Time?,
          default_date : Time?,
          events_by_iso : EventsByISO,
          *,
          adjacent_prev_month : Bool = false,
          adjacent_next_month : Bool = false,
        ) : CalendarCell
          iso = format_iso(date.year, date.month, day)
          today_flag = same_day?(date, @today)
          disabled_flag = disabled?(date, min_date, max_date)
          selected_flag = selected?(date, default_date, disabled_flag)
          events = events_by_iso[iso]? || [] of Marten::Template::Value

          CalendarCell.new(
            day,
            iso,
            events: events,
            today: today_flag,
            disabled: disabled_flag,
            selected: selected_flag,
            adjacent_prev_month: adjacent_prev_month,
            adjacent_next_month: adjacent_next_month
          )
        end

        private def visible_date_range(
          year : Int32,
          month : Int32,
          monday_start : Bool,
          fill_adjacent : Bool,
        ) : {Time, Time}
          first_day = Time.utc(year, month, 1)
          days_in_month = Time.days_in_month(year, month)
          first_weekday = monday_start ? (first_day.day_of_week.value - 1) : (first_day.day_of_week.value % 7)
          trailing = (7 - ((first_weekday + days_in_month) % 7)) % 7
          last_day = Time.utc(year, month, days_in_month)

          if fill_adjacent
            {first_day - first_weekday.days, last_day + trailing.days}
          else
            {first_day, last_day}
          end
        end

        private def build_events_index(
          events : CalendarEvents,
          visible_start : Time,
          visible_end : Time,
        ) : EventsByISO
          events_by_iso = Hash(String, CalendarEvents).new { |hash, key| hash[key] = [] of Marten::Template::Value }

          events.each do |event|
            start_date = event_start_date(event)
            end_date = event_end_date(event) || start_date

            if date_lt?(end_date, start_date)
              raise Marten::Template::Errors::UnsupportedValue.new(
                "Calendar event #{event.raw.inspect} has an end_time before its start_time"
              )
            end

            clipped_start = date_lt?(start_date, visible_start) ? visible_start : start_date
            clipped_end = date_gt?(end_date, visible_end) ? visible_end : end_date
            next if date_gt?(clipped_start, clipped_end)

            cursor = clipped_start
            loop do
              events_by_iso[format_iso(cursor.year, cursor.month, cursor.day)] << event
              break if same_day?(cursor, clipped_end)
              cursor += 1.day
            end
          end

          events_by_iso
        end

        private def event_start_date(event : Marten::Template::Value) : Time
          value = fetch_event_attribute!(event, "start_time")
          parse_event_date!(value, "start_time", event)
        end

        private def event_end_date(event : Marten::Template::Value) : Time?
          value = fetch_event_attribute(event, "end_time")
          return nil if value.nil?
          return nil if value.not_nil!.raw.nil?

          parse_event_date!(value.not_nil!, "end_time", event)
        end

        private def fetch_event_attribute(event : Marten::Template::Value, key : String) : Marten::Template::Value?
          event[key]
        rescue Marten::Template::Errors::UnknownVariable
          nil
        end

        private def fetch_event_attribute!(event : Marten::Template::Value, key : String) : Marten::Template::Value
          event[key]
        rescue Marten::Template::Errors::UnknownVariable
          raise Marten::Template::Errors::UnsupportedValue.new(
            "Calendar event #{event.raw.inspect} must expose #{key}"
          )
        end

        private def parse_event_date!(
          value : Marten::Template::Value,
          key : String,
          event : Marten::Template::Value,
        ) : Time
          if parsed = DateInputParser.parse(value)
            return parsed
          end

          raise Marten::Template::Errors::UnsupportedValue.new(
            "Calendar event #{event.raw.inspect} has an invalid #{key} value (#{value.raw.inspect})"
          )
        end

        private def localized_weekday_names(monday_start : Bool) : Array(String)
          keys = monday_start ? WEEKDAY_KEYS_MONDAY_START : WEEKDAY_KEYS_SUNDAY_START
          keys.map { |key| I18n.t!("marten_calendar.calendar.weekday_names.#{key}") }
        end

        private def month_title(month : Int32) : String
          key = MONTH_KEYS[month - 1]
          I18n.t!("marten_calendar.calendar.month_names.#{key}")
        end

        private def prev_month_tuple(y : Int32, m : Int32) : {Int32, Int32}
          m == 1 ? {y - 1, 12} : {y, m - 1}
        end

        private def next_month_tuple(y : Int32, m : Int32) : {Int32, Int32}
          m == 12 ? {y + 1, 1} : {y, m + 1}
        end

        private def same_day?(a : Time, b : Time) : Bool
          au = a.to_utc; bu = b.to_utc
          au.year == bu.year && au.month == bu.month && au.day == bu.day
        end

        private def disabled?(date : Time, min : Time?, max : Time?) : Bool
          (!min.nil? && date_lt?(date, min.not_nil!)) ||
            (!max.nil? && date_gt?(date, max.not_nil!))
        end

        private def selected?(date : Time, default : Time?, disabled_flag : Bool) : Bool
          return false unless default
          return false if disabled_flag
          same_day?(date, default.not_nil!)
        end

        private def date_lt?(a : Time, b : Time) : Bool
          {a.year, a.month, a.day} < {b.year, b.month, b.day}
        end

        private def date_gt?(a : Time, b : Time) : Bool
          {a.year, a.month, a.day} > {b.year, b.month, b.day}
        end

        private def format_iso(y : Int32, m : Int32, d : Int32) : String
          "#{y}-#{sprintf("%02d", m)}-#{sprintf("%02d", d)}"
        end

        WEEKDAY_KEYS_MONDAY_START = %w(
          monday
          tuesday
          wednesday
          thursday
          friday
          saturday
          sunday
        )

        WEEKDAY_KEYS_SUNDAY_START = %w(
          sunday
          monday
          tuesday
          wednesday
          thursday
          friday
          saturday
        )

        MONTH_KEYS = %w(
          january
          february
          march
          april
          may
          june
          july
          august
          september
          october
          november
          december
        )
      end
    end
  end
end
