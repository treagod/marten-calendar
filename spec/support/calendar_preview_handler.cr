class CalendarPreviewHandler < Marten::Handlers::Template
  template_name "marten_calendar.html"

  before_render :set_calendar_context

  private def set_calendar_context
    now = Time.local
    year = query_year || now.year
    month = query_month || now.month

    context[:calendar_year] = year
    context[:calendar_month] = month
  end

  private def query_year : Int32?
    request.query_params["year"]?.try &.to_i?
  end

  private def query_month : Int32?
    request.query_params["month"]?.try &.to_i?.try do |value|
      value if (1..12).includes?(value)
    end
  end
end
