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
          events = resolve_events("events")

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
            cell_template_path,
            events
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

          DateInputParser.parse(value) || raise_invalid_date!(key, value)
        end

        private def resolve_events(key : String) : Array(Marten::Template::Value)
          expression = @kwargs[key]?
          return [] of Marten::Template::Value unless expression

          value = expression.resolve(@context)
          return [] of Marten::Template::Value if value.raw.nil?

          events = [] of Marten::Template::Value

          begin
            value.each do |event|
              events << event
            end
          rescue Marten::Template::Errors::UnsupportedType
            raise Marten::Template::Errors::UnsupportedValue.new(
              "Invalid #{key} value provided to calendar tag (expected iterable, got #{value.raw.class})"
            )
          end

          events
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
    end
  end
end
