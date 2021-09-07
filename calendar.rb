#!/usr/bin/ruby

# https://developers.google.com/calendar/api/quickstart/ruby
# https://developers.google.com/calendar/api/guides/create-events

require "google/apis/calendar_v3"

# for debugging, add 'binding.pry' to breakpoint
# require 'pry'

class Calendar

  def initialize(authorization, app_name, cfg)
    @cfg = cfg
    @service = Google::Apis::CalendarV3::CalendarService.new
    @service.client_options.application_name = app_name
    @service.authorization = authorization
  end

  def synchronize_coming_events(events)
    # sort events by calendar
    events_by_calendar = {}
    events.each do |event|
      if not events_by_calendar.has_key? event[:calendar] then
        events_by_calendar[event[:calendar]] = []
      end
      events_by_calendar[event[:calendar]] << event
    end

    events_by_calendar.each do |calendar_id, cal_events|
      g_cal_events = _convert_events(cal_events)
      _synchronize_calendar(calendar_id, g_cal_events)
    end
  end

  # Converts events to Google Calendar format
  def _convert_events(events)
    g_events = []
    events.each do |event|
      source = Google::Apis::CalendarV3::Event::Source.new(
        title: @cfg['calendar']['eventSource']['title'],
        url: @cfg['calendar']['eventSource']['url'],
      )
      g_event = Google::Apis::CalendarV3::Event.new(
        summary: event[:summary],
        location: event[:location],
        description: event[:description],
        start: _convert_to_calendar_time(event[:time]),
        end: _convert_to_calendar_time(event[:ends]),
        source: source,
      )
      g_events << g_event
    end
    g_events
  end

  def _synchronize_calendar(calendar_id, new_events)
    old_events = _get_coming_events(calendar_id)
    _synchronize(new_events, old_events, calendar_id)
  end

  # Returns hash of tasks, time as key
  def _find_meeting_tasks(tasks, meeting_name)
    meeting_tasks = {}
    tasks.each do |task|
      if task[:meeting] == meeting_name
        if not meeting_tasks.has_key? task[:time]
          meeting_tasks[task[:time]] = []
        end
        meeting_tasks[task[:time]] << task
      end
    end
    meeting_tasks
  end

  def _get_coming_events(calendar_id)
    result = @service.list_events(
      calendar_id,
      single_events: true,
      order_by: 'startTime',
      time_min: DateTime.now.to_s,
    )

    # filter only events that are created by this script
    events = []
    result.items.each do |event|
      if event.source && event.source.title == @cfg['calendar']['eventSource']['title']
        events << event
      end
    end
    events
  end

  def _synchronize(new_events, cal_events, calendar_id)
    # update or create calendar events
    new_events.each do |new_event|
      cal_event = _find_event(cal_events, new_event)
      if cal_event
        if not _events_data_is_equal(cal_event, new_event)
          _update_event(cal_event, new_event, calendar_id)
        end
      else
        _insert_event(new_event, calendar_id)
      end
    end

    # delete calendar events
    cal_events.each do |cal_event|
      new_event = _find_event(new_events, cal_event)
      if not new_event
        _delete_event(cal_event, calendar_id)
      end
    end
  end

  def _find_event(events, event)
    events.each do |e|
      if _events_match(e, event)
        return e
      end
    end
    nil
  end

  # Returns true if events start at the same time and they have same source
  def _events_match(e1, e2)
    e1.source && e2.source && e1.source.title == e2.source.title && e1.start.date_time.to_s == e2.start.date_time.to_s
  end

  # Returns true if events have same summary and description
  def _events_data_is_equal(cal_event, new_event)
    cal_event.summary == new_event.summary &&
      cal_event.description == new_event.description &&
      cal_event.location == new_event.location
  end

  def _convert_to_calendar_time(time)
    # Google wants timestamp in format '2015-05-28T17:00:00-07:00'
    s = time.strftime("%Y-%m-%dT%H:%M:%S%z")
    # add ':' to timezone
    s = s[0..21] + ':' + s[22..23]

    cal_time = Google::Apis::CalendarV3::EventDateTime.new(
      date_time: s,
      time_zone: @cfg['calendar']['timeZone'],
    )
    cal_time
  end

  def _insert_event(event, calendar_id)
    puts "INSERT event " + event.start.date_time.to_s
    @service.insert_event(calendar_id, event)
  end

  def _update_event(cal_event, new_event, calendar_id)
    puts "UPDATE event " + cal_event.start.date_time.to_s
    @service.update_event(calendar_id, cal_event.id, new_event)
  end

  def _delete_event(event, calendar_id)
    puts "DELETE event " + event.start.date_time.to_s
    @service.delete_event(calendar_id, event.id)
    # STDERR.puts "ERROR: Could not delete event from calendar '#{calendar_id}': #{result.response.status}"
  end

  def _get_meeting_cfg(meeting)
    @meetings_cfg.each do |meeting_cfg|
      if meeting_cfg['name'] === meeting
        return meeting_cfg
      end
    end
    nil
  end
end
