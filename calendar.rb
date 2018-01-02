#!/usr/bin/ruby

class Calendar

  def initialize(client, cfg)
    @client = client
    @cfg = cfg
    @calendar_api = @client.discovered_api('calendar', 'v3')
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
      g_event = {}
      g_event['summary'] = event[:summary]
      g_event['description'] = event[:description]
      g_event['location'] = event[:location]
      g_event['start'] = {
        'dateTime' => _time_to_google(event[:time])
      }
      g_event['end'] = {
        'dateTime' => _time_to_google(event[:time] + event[:duration])
      }
      g_event['source'] = {
        'title' => @cfg['calendar']['eventSource']['title'],
        'url' => @cfg['calendar']['eventSource']['url']
      }
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
    parameters = {
      'calendarId' => calendar_id,
      'timeMin' => DateTime.now.to_s
    }
    result = @client.execute(:api_method => @calendar_api.events.list,
                             :parameters => parameters,
                             :authorization => @client.authorization.dup)

    if result.response.status != 200
      STDERR.puts "ERROR: Could not read events from calendar '#{calendar_id}': #{result.data.error}"
    end

    # filter only events that are created by this script
    events = []
    result.data.items.each do |event|
      if event.source && event.source.title == @cfg['calendar']['eventSource']['title']
        events << event
      end
    end
    events
  end

  # Convert Time object to '2011-06-03T10:25:00.000-07:00'
  def _time_to_google(time)
    s = time.strftime("%Y-%m-%dT%H:%M:%S.000%z")
    s[0..25] + ':' + s[26..27]
  end

  # Convert Google dateTime '2011-06-03T10:25:00.000-07:00' to Time
  # object
  def _google_to_time(dt)
    d = elems[0].content.split('.')
    t = elems[2].content.split(':')
    Time.new('20' + d[2], d[1], d[0], t[0], t[1])
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
    e1 = _make_hash(e1)
    e2 = _make_hash(e2)
    e1['source'] && e2['source'] && e1['source']['title'] === e2['source']['title'] && e1['_start'] == e2['_start']
  end

  # Returns true if events have same summary and description
  def _events_data_is_equal(cal_event, new_event)
    cal_event.summary == new_event['summary'] &&
      cal_event.description == new_event['description'] &&
      cal_event.location == new_event['location']
  end

  def _make_hash(event)
    if event != Hash
      event = event.to_hash
      event['_start'] = DateTime.parse(event['start']['dateTime'])
    end
    event
  end

  def _insert_event(event, calendar_id)
    puts "INSERT event " + event['start']['dateTime'].to_s
     # Fetch list of events on the user's default calandar
    result = @client.execute(:api_method => @calendar_api.events.insert,
                             :parameters => {'calendarId' => calendar_id},
                             :body => JSON.dump(event),
                             :headers => { 'Content-Type' => 'application/json' },
                             :authorization => @client.authorization.dup)
    if result.response.status != 200
      STDERR.puts "ERROR: Could not insert event to calendar '#{calendar_id}': #{result.data.error}"
    end
  end

  def _update_event(cal_event, new_event, calendar_id)
    puts "UPDATE event " + cal_event.start.dateTime.to_s
    result = @client.execute(:api_method => @calendar_api.events.update,
                             :parameters => {
                              'calendarId' => calendar_id,
                              'eventId' => cal_event.id
                             },
                             :body_object => new_event,
                             :headers => { 'Content-Type' => 'application/json' },
                             :authorization => @client.authorization.dup)
    if result.response.status != 200
      STDERR.puts "ERROR: Could not update event in calendar '#{calendar_id}': #{result.data.error}"
    end
  end

  def _delete_event(event, calendar_id)
    puts "DELETE event " + event.start.dateTime.to_s
    result = @client.execute(:api_method => @calendar_api.events.delete,
                             :parameters => {
                              'calendarId' => calendar_id,
                              'eventId' => event.id
                             }
                             )
    if result.response.status != 200
      STDERR.puts "ERROR: Could not delete event from calendar '#{calendar_id}': #{result.response.status}"
    end
  end

  # Convert Time object to '2011-06-03T10:25:00.000-07:00'
  def _time_to_google(time)
    s = time.strftime("%Y-%m-%dT%H:%M:%S.000%z")
    s[0..25] + ':' + s[26..27]
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
