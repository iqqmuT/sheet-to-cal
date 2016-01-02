#!/usr/bin/ruby

require 'google_drive'
require './expression_finder'
require './expression_parser'

class SpreadsheetParser

  def initialize(client, cfg)
    @client = client
    @cfg = cfg
    @session = GoogleDrive.login_with_oauth(client.authorization.access_token)
  end

  # Format of returned events:
  # {:calendar=>"abcdefg@group.calendar.google.com",
  #  :time=>2016-01-28 18:45:00 +0200,
  #  :summary=>"My summary",
  #  :description=>"Desc",
  #  :location=>"Location",
  #  :duration=>6300
  # }
  def get_coming_events
    rows = []
    @sources = _get_sources()

    @sources.each do |name,value|
      value['sheets'].each do |sheet_title|
        rows += _parse_worksheet(value['spreadsheet'], sheet_title)
      end
    end

    rows_by_time = {}
    rows.each do |row|
      if not rows_by_time.has_key? row[:time] then
        rows_by_time[row[:time]] = []
      end
      rows_by_time[row[:time]] << row
    end

    events = []
    @cfg['commonEvents'].each do |commonEvent|
      events += _gen_common_events(commonEvent, rows, rows_by_time)
    end

    return events
  end

  def _gen_common_events(event, rows, rows_by_time)
    # find all expressions (variables) used in common event
    exp_finder = ExpressionFinder.new
    expressions = exp_finder.find(event['summary'])
    expressions += exp_finder.find(event['description'])
    expressions += exp_finder.find(event['location'])
    expressions.uniq!

    # get all possible times
    #times = []
    variables_by_time = {}
    expressions.each do |expression|
      _find_variables_by_time(variables_by_time, expression, rows)
    end

    events = []
    variables_by_time.each do |time,variables|
      # generate events
      parser = ExpressionParser.new(variables)
      summary = parser.parse(event['summary'])
      description = parser.parse(event['description'])
      location = parser.parse(event['location'])
      new_event = {
        :calendar => @cfg['calendars'][event['calendar']],
        :time => time,
        :summary => summary,
        :description => description,
        :location => location,
        :duration => event['duration']
      }
      events << new_event
    end
    events
  end

  def _find_variables_by_time(variables_by_time, variable, rows)
    if @cfg['variables'].has_key? variable then
      var_arr = @cfg['variables'][variable]
      spreadsheet = @sources[var_arr[0]]['spreadsheet']

      rows.each do |row|
        value = row[:values][var_arr[2]]
        if row[:spreadsheet] == spreadsheet and
           row[:worksheet].title == var_arr[1] and
           value != "" then
          # matching row found
          if not variables_by_time.has_key? row[:time] then
            variables_by_time[row[:time]] = {}
          end
          variables_by_time[row[:time]][variable] = value

        end
      end
    end
    variables_by_time
  end

  # format of row:
  # {
  #   :spreadsheet => <GoogleDrive::Spreadsheet ... title="Foo">,
  #   :worksheet => <GoogleDrive::Worksheet ... title="English">,
  #   :time => 2016-01-06 12:00:00 +0200,
  #   :values => ["6.1.2016 klo 12.00.00", "Place 1", "Foo"]
  # }
  def _parse_worksheet(spreadsheet, sheet_title)
    rows = []
    worksheet = spreadsheet.worksheet_by_title(sheet_title)
    if worksheet && worksheet.rows.length > 1
      worksheet.rows.drop(1).each do |row|
        time = _parse_time(row[@cfg['default']['columns']['time']])
        if time && time > Time.now && _row_contains_data(row)
          rows << { spreadsheet: spreadsheet, worksheet: worksheet, time: time, values: row }
        end
      end
    end
    rows
  end

  def _row_contains_data(row)
    row[1..-1].each do |value|
      if value.length > 0 then
        return true
      end
      return false
    end
  end

  # Returns Set of variable names found from text
  def _find_variables(text)
    return Set.new
  end

  # Returns dictionary of all needed spreadsheets and their sheets
  def _get_sources()
    sources = {}
    @cfg['spreadsheets'].each do |name,key|
      sources[name] = {}
      sources[name]['spreadsheet'] = @session.spreadsheet_by_key(key)
      sources[name]['sheets'] = Set.new

      @cfg['variables'].values.each do |value|
        if value[0] == name then
          sources[name]['sheets'].add(value[1])
        end
      end
    end
    sources
  end

  def _get_spreadsheet(cfg)
    url = cfg['spreadsheetUrl']
    if url
      @session.spreadsheet_by_url(url)
    else
      nil
    end
  end

  def _parse_time(value)
    parse_cfg = @cfg['timeParsing']
    re = Regexp.new(parse_cfg['regExp'])
    matches = value.scan(re)
    if matches.length < 1
      STDERR.puts "ERROR: invalid time value in sheet: '#{value}'"
      return nil
    end
    values = matches[0]
    tu = {}
    parse_cfg['format'].each_with_index do |unit, i|
      tu[unit] = values[i]
    end
    Time.new(tu['year'], tu['month'], tu['day'], tu['hour'], tu['min'], tu['sec'])
  end

end
