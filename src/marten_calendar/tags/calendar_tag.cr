require "uri"

module MartenCalendar
  module Tags
    class CalendarTag < Marten::Template::Tag::Base
      include Marten::Template::Tag::CanExtractKwargs

      @kwargs = {} of String => Marten::Template::FilterExpression

      struct CalendarCell
        include Marten::Template::Object::Auto

        getter day : Int32?
        getter iso : String?

        getter? today : Bool
        getter? disabled : Bool
        getter? selected : Bool
        getter? adjacent_prev_month : Bool
        getter? adjacent_next_month : Bool

        @today : Bool
        @disabled : Bool
        @selected : Bool
        @adjacent_prev_month : Bool
        @adjacent_next_month : Bool

        def initialize(
          @day : Int32?,
          @iso : String?,
          *,
          today : Bool = false,
          disabled : Bool = false,
          selected : Bool = false,
          adjacent_prev_month : Bool = false,
          adjacent_next_month : Bool = false,
        )
          @today = today
          @disabled = disabled
          @selected = selected
          @adjacent_prev_month = adjacent_prev_month
          @adjacent_next_month = adjacent_next_month
        end

        def blank? : Bool
          @day.nil?
        end

        def has_classes? : Bool
          today? || disabled? || selected? || adjacent_prev_month? || adjacent_next_month? || blank?
        end
      end

      struct MonthCalendar
        include Marten::Template::Object::Auto

        getter month : Int32
        getter month_title : String
        getter year : Int32
        getter weekday_names : Array(String)
        getter calendar_cells : Array(Array(CalendarCell))
        getter prev_year : Int32
        getter prev_month : Int32
        getter next_year : Int32
        getter next_month : Int32

        def initialize(
          @month : Int32,
          @month_title : String,
          @year : Int32,
          @weekday_names : Array(String),
          @calendar_cells : Array(Array(CalendarCell)),
          @prev_year : Int32,
          @prev_month : Int32,
          @next_year : Int32,
          @next_month : Int32,
        )
        end
      end

      def initialize(parser : Marten::Template::Parser, source : String)
        extract_kwargs(source).each do |key, value|
          @kwargs[key] = Marten::Template::FilterExpression.new(value)
        end
      end

      def render(context : Marten::Template::Context) : String
        year_in = resolve_int(context, "year") || Time.local.year
        month_in = resolve_int(context, "month") || Time.local.month
        year, month = normalize_year_month(year_in, month_in)

        monday_start = parse_week_start(resolve_str(context, "week_start"))
        fill_adjacent = resolve_bool(context, "fill_adjacent", false)

        min_date = resolve_date(context, "min")
        max_date = resolve_date(context, "max")
        default_date = resolve_date(context, "default")

        tmpl_path = resolve_str(context, "template") || Marten.settings.calendar.template_path
        cell_tmpl_path = resolve_str(context, "cell_template") || Marten.settings.calendar.cell_template_path

        first_day = Time.utc(year, month, 1)
        days_in_month = Time.days_in_month(year, month)
        first_weekday = monday_start ? (first_day.day_of_week.value - 1) : (first_day.day_of_week.value % 7)
        weekday_names = localized_weekday_names(monday_start)

        prev_y, prev_m = prev_month_tuple(year, month)
        next_y, next_m = next_month_tuple(year, month)
        prev_dim = Time.days_in_month(prev_y, prev_m)
        today = today_utc

        calendar_cells = if fill_adjacent && first_weekday > 0
                           start_d = prev_dim - first_weekday + 1
                           cells = Array(CalendarCell).new
                           start_d.upto(prev_dim) do |d|
                             date = Time.utc(prev_y, prev_m, d)
                             iso = format_iso(prev_y, prev_m, d)
                             today_flag = same_day?(date, today)
                             disabled_flag = disabled?(date, min_date, max_date)
                             selected_flag = selected?(date, default_date, disabled_flag)
                             cells << CalendarCell.new(
                               d,
                               iso,
                               today: today_flag,
                               disabled: disabled_flag,
                               selected: selected_flag,
                               adjacent_prev_month: true
                             )
                           end
                           cells
                         else
                           Array(CalendarCell).new(first_weekday) do |_idx|
                             CalendarCell.new(nil, nil)
                           end
                         end

        day = 1
        while day <= days_in_month
          date = Time.utc(year, month, day)
          iso = format_iso(year, month, day)
          today_flag = same_day?(date, today)
          disabled_flag = disabled?(date, min_date, max_date)
          selected_flag = selected?(date, default_date, disabled_flag)
          calendar_cells << CalendarCell.new(
            day,
            iso,
            today: today_flag,
            disabled: disabled_flag,
            selected: selected_flag
          )

          day += 1
        end

        trailing = (7 - ((first_weekday + days_in_month) % 7)) % 7
        if fill_adjacent && trailing > 0
          1.upto(trailing) do |d|
            date = Time.utc(next_y, next_m, d)
            iso = format_iso(next_y, next_m, d)
            today_flag = same_day?(date, today)
            disabled_flag = disabled?(date, min_date, max_date)
            selected_flag = selected?(date, default_date, disabled_flag)
            calendar_cells << CalendarCell.new(
              d,
              iso,
              today: today_flag,
              disabled: disabled_flag,
              selected: selected_flag,
              adjacent_next_month: true
            )
          end
        else
          trailing.times do
            calendar_cells << CalendarCell.new(nil, nil)
          end
        end

        calendar_weeks = calendar_cells.in_slices_of(7)
        month_calendar = MonthCalendar.new(
          month,
          month_title(month),
          year,
          weekday_names,
          calendar_weeks,
          prev_y,
          prev_m,
          next_y,
          next_m
        )

        next_path, previous_path = build_nav_paths(
          context,
          prev_year: prev_y,
          prev_month: prev_m,
          next_year: next_y,
          next_month: next_m
        )

        Marten.templates.get_template(tmpl_path).render({
          "month_calendar"     => month_calendar,
          "cell_template_path" => cell_tmpl_path,
          "next_path"          => next_path,
          "previous_path"      => previous_path,
        })
      end

      private def build_month_year_uri(
        base_uri : URI,
        base_params : URI::Params,
        year : Int32,
        month : Int32,
      ) : String
        params = base_params.dup
        params["year"] = year.to_s
        params["month"] = month.to_s

        nav_uri = base_uri.dup
        nav_uri.query = params.to_s
        nav_uri.to_s
      end

      private def build_nav_paths(
        context : Marten::Template::Context,
        prev_year : Int32,
        prev_month : Int32,
        next_year : Int32,
        next_month : Int32,
      ) : {String?, String?}
        request_wrapper = context[:request]?
        return {nil, nil} unless request_wrapper

        raw = request_wrapper.raw

        unless raw.is_a?(Marten::HTTP::Request)
          return {nil, nil}
        end

        req = raw.as(Marten::HTTP::Request)

        base_uri = URI.parse(req.full_path.dup)
        base_params = extract_query_params(base_uri)

        next_uri = build_month_year_uri(base_uri, base_params, next_year, next_month)
        prev_uri = build_month_year_uri(base_uri, base_params, prev_year, prev_month)

        {next_uri, prev_uri}
      end

      private def date_gt?(a : Time, b : Time) : Bool
        {a.year, a.month, a.day} > {b.year, b.month, b.day}
      end

      private def date_lt?(a : Time, b : Time) : Bool
        {a.year, a.month, a.day} < {b.year, b.month, b.day}
      end

      private def disabled?(date : Time, min : Time?, max : Time?) : Bool
        (!min.nil? && date_lt?(date, min.not_nil!)) ||
          (!max.nil? && date_gt?(date, max.not_nil!))
      end

      private def extract_query_params(uri : URI) : URI::Params
        if query = uri.query
          URI::Params.parse(query)
        else
          URI::Params.new
        end
      end

      private def fetch_localized_date_format(index : Int32) : String?
        I18n.t!("marten.schema.field.date.input_formats.#{index}").to_s
      rescue I18n::Errors::MissingTranslation
        nil
      end

      private def format_iso(y : Int32, m : Int32, d : Int32) : String
        "#{y}-#{sprintf("%02d", m)}-#{sprintf("%02d", d)}"
      end

      private def i18n_date_input_formats : Array(String)
        fmts = [] of String
        idx = 0

        while fmt = fetch_localized_date_format(idx)
          fmts << fmt
          idx += 1
        end

        fmts
      end

      private def localized_weekday_names(monday_start : Bool) : Array(String)
        keys = monday_start ? WEEKDAY_KEYS_MONDAY_START : WEEKDAY_KEYS_SUNDAY_START
        keys.map { |key| I18n.t!("marten_calendar.calendar.weekday_names.#{key}") }
      end

      private def month_title(month : Int32) : String
        key = MONTH_KEYS[month - 1]
        I18n.t!("marten_calendar.calendar.month_names.#{key}")
      end

      private def next_month_tuple(y : Int32, m : Int32) : {Int32, Int32}
        m == 12 ? {y + 1, 1} : {y, m + 1}
      end

      private def normalize_year_month(y : Int32, m : Int32) : {Int32, Int32}
        q, r = (m - 1).divmod(12)
        {y + q, r + 1}
      end

      private def parse_iso_date(s : String) : Time?
        return nil unless s.size >= 10
        y = s[0, 4].to_i?; m = s[5, 2].to_i?; d = s[8, 2].to_i?
        return nil if y.nil? || m.nil? || d.nil?
        Time.utc(y, m, d) rescue nil
      end

      private def parse_localized_date(s : String) : Time?
        tz = Marten.settings.time_zone || Time::Location.load("UTC")

        if t = try_parse(s, "%F", tz)
          return t
        end

        fmts = i18n_date_input_formats + DEFAULT_DATE_INPUT_FORMATS
        fmts.each do |fmt|
          if t = try_parse(s, fmt, tz)
            return t
          end
        end

        nil
      end

      private def parse_week_start(s : String?) : Bool
        case s.try &.downcase
        when "sunday"      then false
        when "monday", nil then true
        else                    true
        end
      end

      private def prev_month_tuple(y : Int32, m : Int32) : {Int32, Int32}
        m == 1 ? {y - 1, 12} : {y, m - 1}
      end

      private def resolve_bool(ctx, key, fallback : Bool) : Bool
        raw = @kwargs[key]?.try(&.resolve(ctx))
        return fallback if raw.nil?
        case raw
        when Bool then raw
        else
          s = raw.to_s.downcase
          {"1", "true", "t", "yes", "y", "on"}.includes?(s)
        end
      end

      private def resolve_date(ctx, key) : Time?
        val = @kwargs[key]?.try(&.resolve(ctx))
        return unless val

        case val
        when Time
          Time.utc(val.year, val.month, val.day)
        when Marten::Template::Value
          v = val.raw
          return v if v.is_a?(Time)
          parse_localized_date(v.to_s)
        else
          parse_iso_date(val.to_s)
        end
      end

      private def resolve_int(ctx, key) : Int32?
        @kwargs[key]?.try { |f| f.resolve(ctx).to_s.to_i? }
      end

      private def resolve_str(ctx, key) : String?
        @kwargs[key]?.try { |f| f.resolve(ctx).to_s }
      end

      private def same_day?(a : Time, b : Time) : Bool
        au = a.to_utc; bu = b.to_utc
        au.year == bu.year && au.month == bu.month && au.day == bu.day
      end

      private def selected?(date : Time, default : Time?, disabled_flag : Bool) : Bool
        return false unless default
        return false if disabled_flag
        same_day?(date, default.not_nil!)
      end

      private def today_utc : Time
        Time.local.to_utc
      end

      private def try_parse(s : String, fmt : String, tz : Time::Location) : Time?
        Time.parse(s, fmt, tz)
      rescue
        nil
      end

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

      DEFAULT_DATE_INPUT_FORMATS = [
        "%Y-%m-%d",
        "%m/%d/%Y",
        "%m/%d/%y",
        "%b %d %Y",
        "%b %d, %Y",
        "%d %b %Y",
        "%d %b, %Y",
        "%B %d %Y",
        "%B %d, %Y",
        "%d %B %Y",
        "%d %B, %Y",
      ]
    end
  end
end
