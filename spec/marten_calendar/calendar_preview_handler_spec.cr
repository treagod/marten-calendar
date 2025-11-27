require "./spec_helper"

describe CalendarPreviewHandler do
  it "renders the current month when no query params are provided" do
    Timecop.freeze(Time.local(2024, 5, 15)) do
      with_calendar_templates do
        handler = CalendarPreviewHandler.new(build_http_request("/calendar"))

        response = handler.dispatch

        response.status.should eq 200
        response.content.should contain "Calendar 5/2024"
      end
    end
  end

  it "uses query parameters to choose the displayed month" do
    with_calendar_templates do
      handler = CalendarPreviewHandler.new(build_http_request("/calendar?month=3&year=2023"))

      response = handler.dispatch

      response.status.should eq 200
      response.content.should contain "Calendar 3/2023"
    end
  end
end
