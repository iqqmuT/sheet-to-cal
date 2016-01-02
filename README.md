# Google Sheets To Calendar
Reads Google Sheets from Google Drive and creates events to Google Calendar.

## Prerequisites ##
Run `bundle install` to install all prerequisities.

## Setup ##

1. Download OAuth 2.0 JSON credential file from Google Developers Console and save it to `client_secret.json`.
2. Copy `config.json.template` to `config.json`.
3. Modify `config.json` according to your needs.

## Running ##
Run `ruby run.rb`

Credentials will be asked and they will be stored to `credentials` directory, so next time they will not be asked.

## Debugging ##

1. Add `gem 'pry-byebug'` to `Gemfile`
2. Run `bundle install`
3. Add `require 'pry'` to Ruby file to be debugged
4. Add `binding.pry` to wanted line in Ruby file
