module MartenCalendar
  module Tags
    module Support
      struct CalendarCell
        include Marten::Template::Object::Auto

        getter day : Int32?
        getter iso : String?
        getter events : Array(Marten::Template::Value)

        getter? today : Bool
        getter? disabled : Bool
        getter? selected : Bool
        getter? adjacent_prev_month : Bool
        getter? adjacent_next_month : Bool

        @today : Bool
        @disabled : Bool
        @selected : Bool
        @adjacent_prev_month : Bool
        @adjacent_next_month : Bool

        def initialize(
          @day : Int32?,
          @iso : String?,
          *,
          events : Array(Marten::Template::Value) = [] of Marten::Template::Value,
          today : Bool = false,
          disabled : Bool = false,
          selected : Bool = false,
          adjacent_prev_month : Bool = false,
          adjacent_next_month : Bool = false,
        )
          @events = events
          @today = today
          @disabled = disabled
          @selected = selected
          @adjacent_prev_month = adjacent_prev_month
          @adjacent_next_month = adjacent_next_month
        end

        def blank? : Bool
          @day.nil?
        end

        def has_classes? : Bool
          today? || disabled? || selected? || adjacent_prev_month? || adjacent_next_month? || blank?
        end
      end
    end
  end
end
