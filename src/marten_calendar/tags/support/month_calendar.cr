module MartenCalendar
  module Tags
    module Support
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
    end
  end
end
