module MartenCalendar
  module Tags
    module Support
      struct CalendarConfig
        getter year : Int32
        getter month : Int32
        getter? monday_start : Bool
        getter? fill_adjacent : Bool
        getter min_date : Time?
        getter max_date : Time?
        getter default_date : Time?
        getter template_path : String
        getter cell_template_path : String

        def initialize(
          @year : Int32,
          @month : Int32,
          @monday_start : Bool,
          @fill_adjacent : Bool,
          @min_date : Time?,
          @max_date : Time?,
          @default_date : Time?,
          @template_path : String,
          @cell_template_path : String,
        )
        end
      end
    end
  end
end
