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
      alias KwargsResolver = Support::KwargsResolver
      alias MonthCalendarBuilder = Support::MonthCalendarBuilder

      def initialize(parser : Marten::Template::Parser, source : String)
        extract_kwargs(source).each do |key, value|
          @kwargs[key] = Marten::Template::FilterExpression.new(value)
        end
      end

      def render(context : Marten::Template::Context) : String
        config = KwargsResolver.new(@kwargs, context).resolve

        builder = MonthCalendarBuilder.new(config, today_utc)
        month_calendar = builder.build

        next_path, previous_path = build_nav_paths(
          context,
          prev_year: month_calendar.prev_year,
          prev_month: month_calendar.prev_month,
          next_year: month_calendar.next_year,
          next_month: month_calendar.next_month
        )

        Marten.templates.get_template(config.template_path).render({
          "month_calendar"     => month_calendar,
          "cell_template_path" => config.cell_template_path,
          "next_path"          => next_path,
          "previous_path"      => previous_path,
        })
      end

      private def today_utc : Time
        Time.local.to_utc
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
