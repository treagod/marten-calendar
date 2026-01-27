module MartenCalendar
  module Tags
    module Support
      class KwargsResolver
        def initialize(
          @kwargs : Hash(String, Marten::Template::FilterExpression),
          @context : Marten::Template::Context,
        )
        end

        def resolve : CalendarConfig
          year_in = resolve_int("year") || Time.local.year
          month_in = resolve_int("month") || Time.local.month
          year, month = normalize_year_month(year_in, month_in)

          monday_start = parse_week_start(resolve_str("week_start"))
          fill_adjacent = resolve_bool("fill_adjacent", false)
          min_date = resolve_date("min")
          max_date = resolve_date("max")
          default_date = resolve_date("default")

          template_path = resolve_str("template") || Marten.settings.calendar.template_path
          cell_template_path = resolve_str("cell_template") || Marten.settings.calendar.cell_template_path

          CalendarConfig.new(
            year,
            month,
            monday_start,
            fill_adjacent,
            min_date,
            max_date,
            default_date,
            template_path,
            cell_template_path
          )
        end

        private def normalize_year_month(y : Int32, m : Int32) : {Int32, Int32}
          q, r = (m - 1).divmod(12)
          {y + q, r + 1}
        end

        private def resolve_int(key) : Int32?
          @kwargs[key]?.try { |f| f.resolve(@context).to_s.to_i? }
        end

        private def resolve_str(key) : String?
          @kwargs[key]?.try { |f| f.resolve(@context).to_s }
        end

        private def resolve_bool(key, fallback : Bool) : Bool
          raw = @kwargs[key]?.try(&.resolve(@context))
          return fallback if raw.nil?
          case raw
          when Bool then raw
          else
            s = raw.to_s.downcase
            {"1", "true", "t", "yes", "y", "on"}.includes?(s)
          end
        end

        private def resolve_date(key) : Time?
          value = @kwargs[key]?.try(&.resolve(@context))
          return if value.nil?

          if value.is_a?(Marten::Template::Value) && value.raw.nil?
            return nil
          end

          parse_date_input(value) || raise_invalid_date!(key, value)
        end

        private def parse_date_input(value) : Time?
          case value
          when Time
            Time.utc(value.year, value.month, value.day)
          when String
            parse_string_date(value)
          when Marten::Template::Value
            parse_date_input(value.raw)
          else
            nil
          end
        end

        private def parse_string_date(value : String) : Time?
          parse_iso_date(value) || parse_localized_date(value)
        end

        private def parse_iso_date(s : String) : Time?
          return nil unless s.size >= 10
          y = s[0, 4].to_i?; m = s[5, 2].to_i?; d = s[8, 2].to_i?
          return nil if y.nil? || m.nil? || d.nil?
          Time.utc(y, m, d) rescue nil
        end

        private def parse_localized_date(s : String) : Time?
          tz = Marten.settings.time_zone || Time::Location.load("UTC")

          fmts = i18n_date_input_formats + DEFAULT_DATE_INPUT_FORMATS
          fmts.each do |fmt|
            if t = try_parse(s, fmt, tz)
              return t
            end
          end

          nil
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

        private def fetch_localized_date_format(index : Int32) : String?
          I18n.t!("marten.schema.field.date.input_formats.#{index}").to_s
        rescue I18n::Errors::MissingTranslation
          nil
        end

        private def try_parse(s : String, fmt : String, tz : Time::Location) : Time?
          Time.parse(s, fmt, tz)
        rescue
          nil
        end

        private def parse_week_start(s : String?) : Bool
          case s.try &.downcase
          when "sunday"      then false
          when "monday", nil then true
          else                    true
          end
        end

        private def raise_invalid_date!(key : String, raw_value) : NoReturn
          shown =
            case raw_value
            when Marten::Template::Value
              raw_value.raw.inspect
            else
              raw_value.inspect
            end

          raise Marten::Template::Errors::UnsupportedValue.new(
            "Invalid #{key} date provided to calendar tag (#{shown})"
          )
        end
      end

      DEFAULT_DATE_INPUT_FORMATS = [
        "%Y-%m-%d",
        "%d.%m.%Y",
        "%d.%m.%y",
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
