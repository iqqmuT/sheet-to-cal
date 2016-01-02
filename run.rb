#!/usr/bin/ruby

require 'bundler/setup'
require 'json'
require 'google/api_client'
require_relative 'authorization'
require_relative 'spreadsheet_parser'
require_relative 'calendar'

CONFIG_FILE = "config.json"

cfg = JSON.parse(IO.read(CONFIG_FILE))

authorization = Authorization.authorize(cfg['clientSecret'])
if !authorization
  abort("Not authorized")
end

client = Google::APIClient.new(
  :application_name => 'Sheet To Cal',
  :application_version => '1.0.0')
client.authorization = authorization

parser = SpreadsheetParser.new(client, cfg)
events = parser.get_coming_events

calendar = Calendar.new(client, cfg)
calendar.synchronize_coming_events(events)
