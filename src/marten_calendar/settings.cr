module MartenCalendar
  class Settings < Marten::Conf::Settings
    namespace :calendar

    @template_path : String = "marten_calendar/month_calendar.html"
    @cell_template_path : String = "marten_calendar/month_calendar_cell.html"

    getter template_path, cell_template_path
    setter template_path, cell_template_path
  end
end
