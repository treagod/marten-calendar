class CalendarSpecEvent
  include Marten::Template::Object::Auto

  getter name : String
  getter start_time : String | Time
  getter end_time : Nil | String | Time

  def initialize(
    @name : String,
    @start_time : String | Time,
    @end_time : Nil | String | Time = nil,
  )
  end
end

class CalendarSpecEventWithoutStartTime
  include Marten::Template::Object::Auto

  getter name : String
  getter end_time : Nil | String | Time

  def initialize(
    @name : String,
    @end_time : Nil | String | Time = nil,
  )
  end
end
