module MartenCalendar
  module Tags
    module Support
      module DateInputParser
        extend self

        def parse(value : Nil) : Nil
          nil
        end

        def parse(value : Time) : Time
          normalize_date(value)
        end

        def parse(value : String) : Time?
          parse_string_date(value)
        end

        def parse(value : Marten::Template::Value) : Time?
          raw = value.raw

          case raw
          when Nil
            nil
          when Time
            normalize_date(raw)
          else
            parse_string_date(value.to_s)
          end
        end

        def parse(value) : Time?
          nil
        end

        private def parse_string_date(value : String) : Time?
          cleaned = value.strip
          return nil if cleaned.empty?

          if parsed = parse_iso_date(cleaned) || parse_configured_date(cleaned)
            normalize_date(parsed)
          end
        end

        private def parse_iso_date(value : String) : Time?
          return nil unless value.bytesize >= 10

          # Intentionally accepts date-time strings by parsing the YYYY-MM-DD prefix.
          iso = value[0, 10]
          return nil unless iso[4] == '-' && iso[7] == '-'

          y = iso[0, 4].to_i?
          m = iso[5, 2].to_i?
          d = iso[8, 2].to_i?
          return nil unless y && m && d

          Time.utc(y, m, d)
        rescue ArgumentError
          nil
        end

        private def parse_configured_date(value : String) : Time?
          tz = Marten.settings.time_zone

          result = nil
          localized_format_index = 0
          fallback_format_index = 0

          while result.nil?
            format = fetch_localized_date_format(localized_format_index)
            localized_format_index += 1

            if format.nil?
              format = Marten.settings.date_input_formats[fallback_format_index]?
              fallback_format_index += 1
            end

            break if format.nil?

            result = begin
              Time.parse(value, format, tz)
            rescue Time::Format::Error
              nil
            end
          end

          result
        end

        private def fetch_localized_date_format(index)
          I18n.t!("marten.schema.field.date.input_formats.#{index}")
        rescue I18n::Errors::MissingTranslation
          nil
        end

        private def normalize_date(value : Time) : Time
          Time.utc(value.year, value.month, value.day)
        end
      end
    end
  end
end
