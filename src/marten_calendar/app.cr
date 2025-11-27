require "./settings"
require "./tags/**"

module MartenCalendar
  class App < Marten::App
    label "marten_calendar"

    def setup
      Marten::Template::Tag.register("calendar", MartenCalendar::Tags::CalendarTag)
    end
  end
end
