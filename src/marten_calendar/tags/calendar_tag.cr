require "uri"
require "./support/**"

module MartenCalendar
  module Tags
    class CalendarTag < Marten::Template::Tag::Base
      include Marten::Template::Tag::CanExtractKwargs

      @kwargs = {} of String => Marten::Template::FilterExpression

      alias CalendarCell = Support::CalendarCell
      alias MonthCalendar = Support::MonthCalendar
      alias CalendarConfig = Support::CalendarConfig
      alias DateInputParser = Support::DateInputParser
      alias KwargsResolver = Support::KwargsResolver
      alias MonthCalendarBuilder = Support::MonthCalendarBuilder

      def initialize(parser : Marten::Template::Parser, source : String)
        extract_kwargs(source).each do |key, value|
          @kwargs[key] = Marten::Template::FilterExpression.new(value)
        end
      end

      def render(context : Marten::Template::Context) : String
        config = KwargsResolver.new(@kwargs, context).resolve

        builder = MonthCalendarBuilder.new(config, today)
        month_calendar = builder.build

        next_path, previous_path = build_nav_paths(
          context,
          prev_year: month_calendar.prev_year,
          prev_month: month_calendar.prev_month,
          next_year: month_calendar.next_year,
          next_month: month_calendar.next_month,
          min_date: config.min_date,
          max_date: config.max_date
        )

        Marten.templates.get_template(config.template_path).render({
          "month_calendar"     => month_calendar,
          "cell_template_path" => config.cell_template_path,
          "next_path"          => next_path,
          "previous_path"      => previous_path,
        })
      end

      private def today : Time
        DateInputParser.parse(Time.utc)
      end

      private def build_nav_paths(
        context : Marten::Template::Context,
        prev_year : Int32,
        prev_month : Int32,
        next_year : Int32,
        next_month : Int32,
        min_date : Time?,
        max_date : Time?,
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

        next_uri =
          if month_selectable?(next_year, next_month, min_date, max_date)
            build_month_year_uri(base_uri, base_params, next_year, next_month)
          end

        prev_uri =
          if month_selectable?(prev_year, prev_month, min_date, max_date)
            build_month_year_uri(base_uri, base_params, prev_year, prev_month)
          end

        {next_uri, prev_uri}
      end

      private def month_selectable?(
        year : Int32,
        month : Int32,
        min_date : Time?,
        max_date : Time?,
      ) : Bool
        month_start = Time.utc(year, month, 1)
        month_end = Time.utc(year, month, Time.days_in_month(year, month))

        return false if min_date && month_end < min_date
        return false if max_date && month_start > max_date

        true
      end

      private def extract_query_params(uri : URI) : URI::Params
        if query = uri.query
          URI::Params.parse(query)
        else
          URI::Params.new
        end
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
    end
  end
end
