#!/usr/bin/ruby

# https://developers.google.com/sheets/api/quickstart/ruby
# https://developers.google.com/sheets/api/reference/rest/v4/spreadsheets/get

require "google/apis/sheets_v4"
require_relative 'authorization'
require './expression_finder'
require './expression_parser'

# for debugging, add 'binding.pry' to breakpoint
# require 'pry'

class SpreadsheetParser

  def initialize(authorization, app_name, cfg)
    @cfg = cfg
    @service = Google::Apis::SheetsV4::SheetsService.new
    @service.client_options.application_name = app_name
    @service.authorization = authorization
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
        :ends => time + event['duration'],
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
          row[:worksheet].properties.title == var_arr[1] and value != "" then
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
    # worksheet = spreadsheet.worksheet_by_title(sheet_title)
    worksheet = _get_sheet_by_title(spreadsheet, sheet_title)
    if worksheet && worksheet.data.length > 0 then
      range = worksheet.data[0] # first data range
      range.row_data.drop(1).each do |row|
        if row.values then
          time = _parse_time(row.values[@cfg['default']['columns']['time']].formatted_value)
          if time && time > Time.now && _row_contains_data(row)
            rows << {
              spreadsheet: spreadsheet,
              worksheet: worksheet,
              time: time,
              values: _read_row_values(row),
            }
          end
        end
      end
    end
    rows
  end

  def _read_row_values(row)
    values = []
    row.values.each do |cell|
      if cell then
        values.append(cell.formatted_value ? cell.formatted_value : '')
      end
    end
    values
  end

  def _row_contains_data(row)
    row.values[1..-1].each do |value|
      if value && value.formatted_value && value.formatted_value.length > 0 then
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
      # fetch spreadsheet with data
      sources[name]['spreadsheet'] = @service.get_spreadsheet(key, include_grid_data: true)
      sources[name]['sheets'] = Set.new

      @cfg['variables'].values.each do |value|
        if value[0] == name then
          sources[name]['sheets'].add(value[1])
        end
      end
    end
    sources
  end

  def _parse_time(value)
    if value == nil then
      return nil
    end
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

  def _get_sheet_by_title(spreadsheet, title)
    spreadsheet.sheets.each do |sheet|
      if sheet.properties.title == title then
        return sheet
      end
    end
    # not found
    return nil
  end

end
