ENV["MARTEN_ENV"] = "test"

require "spec"
require "timecop"

require "marten"
require "marten/spec"
require "sqlite3"

require "../src/marten_calendar"
require "./support/**"

module MartenCalendarSpec
  TEMPLATE_ROOT      = File.expand_path("../src/marten_calendar/templates", __DIR__)
  SPEC_TEMPLATE_ROOT = File.expand_path("./marten_calendar/templates", __DIR__)
end

def with_calendar_templates(include_request_context : Bool = false, &)
  MartenCalendar::App.new.setup
  Marten.setup_templates

  original_loaders = Marten.templates.loaders.dup.as(Array(Marten::Template::Loader::Base))
  original_context_producers = Marten.templates.context_producers
    .dup
    .as(Array(Marten::Template::ContextProducer))

  loaders = [
    Marten::Template::Loader::FileSystem.new(MartenCalendarSpec::TEMPLATE_ROOT),
    Marten::Template::Loader::FileSystem.new(MartenCalendarSpec::SPEC_TEMPLATE_ROOT),
  ] of Marten::Template::Loader::Base

  Marten.templates.loaders = loaders

  if include_request_context
    Marten.templates.context_producers = [
      Marten::Template::ContextProducer::Request.new,
    ] of Marten::Template::ContextProducer
  end

  yield
ensure
  if loaders = original_loaders
    Marten.templates.loaders = loaders
  end

  if context_producers = original_context_producers
    Marten.templates.context_producers = context_producers
  end
end

def build_http_request(path : String = "/calendar")
  Marten::HTTP::Request.new(
    ::HTTP::Request.new(
      method: "GET",
      resource: path,
      headers: HTTP::Headers{"Host" => "example.com"}
    )
  )
end
