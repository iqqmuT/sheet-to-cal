#!/usr/bin/ruby

require 'rubygems'

require "google/apis/calendar_v3"
require "google/apis/sheets_v4"
require "googleauth"
require "googleauth/stores/file_token_store"

require 'fileutils'

module Authorization

  # CREDENTIALS_PATH = File.join('credentials', 'token.yaml')
  TOKEN_PATH = 'credentials/token.yaml'.freeze
  OOB_URI = "urn:ietf:wg:oauth:2.0:oob".freeze
  SCOPES = [
    Google::Apis::CalendarV3::AUTH_CALENDAR_EVENTS,
    Google::Apis::SheetsV4::AUTH_SPREADSHEETS_READONLY,
  ]

  def self.authorize(client_secrets_file)
    client_id = Google::Auth::ClientId.from_file client_secrets_file
    token_store = Google::Auth::Stores::FileTokenStore.new file: TOKEN_PATH
    authorizer = Google::Auth::UserAuthorizer.new client_id, SCOPES, token_store
    user_id = "default"
    credentials = authorizer.get_credentials user_id
    if credentials.nil?
      url = authorizer.get_authorization_url base_url: OOB_URI
      puts "Open the following URL in the browser and enter the " \
           "resulting code after authorization:\n" + url
      code = gets
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: user_id, code: code, base_url: OOB_URI
      )
      puts "Credentials saved to #{TOKEN_PATH}" unless credentials.nil?
    end
    credentials
  end

  def self.get_app_name()
    "Sheet To Cal"
  end

end
