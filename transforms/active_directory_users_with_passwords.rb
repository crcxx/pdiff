#!/usr/bin/env ruby
require 'rubygems'
require 'bundler/setup'

## gems
require 'nokogiri'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'mimi_parser'

def main
  name = ARGV[0]
  short_name = nil

  if ARGV[1]
    short_name = ARGV[1]
  end

  matched = {}
  mimi=MimiParser.new
  creds = mimi.get_creds

  creds.each do |key,cred|
    if cred[:domain] == name
      matched[key] = cred unless matched.keys.include? key
    end
    if cred[:domain] == short_name
      matched[key] = cred unless matched.keys.include? key
    end
  end

  builder = Nokogiri::XML::Builder.new do |xml|
    xml.MaltegoMessage {
      xml.MaltegoTransformResponseMessage {
        xml.Entities {
          matched.each do |key,cred|
            xml.Entity(:Type => 'crcx.ActiveDirectoryUser') {
              xml.Value cred[:username]
              xml.AdditionalFields {
                xml.Field(:Name => 'user.password', :DisplayName => 'Password', :MatchingRule => 'strict').text(cred[:password])
              }
            }
          end
        }
      }
    }
  end
  puts builder.to_xml
end

if __FILE__ == $PROGRAM_NAME
  main
end
