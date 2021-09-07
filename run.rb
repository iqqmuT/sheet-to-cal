#!/usr/bin/ruby

require 'bundler/setup'
require 'json'
require_relative 'authorization'
require_relative 'spreadsheet_parser'
require_relative 'calendar'

CONFIG_FILE = "config.json"

cfg = JSON.parse(IO.read(CONFIG_FILE))

authorization = Authorization.authorize(cfg['clientSecret'])
if !authorization
  abort("Not authorized")
end

app_name = 'Sheet To Cal'.freeze

parser = SpreadsheetParser.new(authorization, app_name, cfg)
events = parser.get_coming_events

calendar = Calendar.new(authorization, app_name, cfg)
calendar.synchronize_coming_events(events)
