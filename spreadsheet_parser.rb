#!/usr/bin/ruby

# https://developers.google.com/sheets/api/quickstart/ruby
# https://developers.google.com/sheets/api/reference/rest/v4/spreadsheets/get
# https://googleapis.dev/ruby/google-api-client/latest/Google/Apis/SheetsV4/SheetsService.html#get_spreadsheet-instance_method

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
    @values = _read_values()

    @values.each do |spreadsheet, worksheet_data|
      worksheet_data.each do |worksheet, data_rows|
        data_rows.each do |row|
          time = _parse_time(row[@cfg['default']['columns']['time']])
          if time && time > Time.now && _row_contains_data(row)
            rows << {
              spreadsheet: spreadsheet,
              worksheet: worksheet,
              time: time,
              values: row,
            }
          end
        end
      end
    end

    rows_by_time = {}
    rows.each do |row|
      if not rows_by_time.has_key? row[:time] then
        rows_by_time[row[:time]] = []
      end
      rows_by_time[row[:time]] << row
    end

    #puts(rows_by_time)

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
      spreadsheet_title = var_arr[0]

      rows.each do |row|
        value = row[:values][var_arr[2]]
        if row[:spreadsheet] == spreadsheet_title and
          row[:worksheet] == var_arr[1] and value != "" then
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
    if row.length < 2 then
      return false
    end
    row[1..-1].each do |value|
      if value && value.length > 0 then
        return true
      end
      return false
    end
  end

  # Returns Set of variable names found from text
  def _find_variables(text)
    return Set.new
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

  def _get_sheet_titles()
    # get list of sheets we need to fetch
    sheet_titles = {}
    @cfg['variables'].values.each do |main_title, sheet_title, col|
      if !sheet_titles.keys.include?(main_title) then
        sheet_titles[main_title] = { titles: [], cols: 1 }
      end
      if !sheet_titles[main_title][:titles].include?(sheet_title) then
        sheet_titles[main_title][:titles].append(sheet_title)
      end
      if col > sheet_titles[main_title][:cols] then
        sheet_titles[main_title][:cols] = col
      end
    end
    sheet_titles
  end

  def _read_values()
    titles = _get_sheet_titles()

    values = {}
    titles.keys.each do |main_title|
      id = @cfg['spreadsheets'][main_title]
      titles[main_title][:titles].each do |sheet_title|
        # generate range string, start from 2nd row
        range = sheet_title + '!' + 'A2:' + ((65 + titles[main_title][:cols]).chr) + "#{@cfg['readRows']}"
        # read sheet data by range
        range_values = @service.get_spreadsheet_values(id, range)

        if !values.has_key?(main_title) then
          values[main_title] = {}
        end
        values[main_title][sheet_title] = range_values.values
      end
    end
    values
  end

end
