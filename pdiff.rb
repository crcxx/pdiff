#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'

# stdlib
require 'fileutils'
require 'optparse'
require 'ostruct'
require 'set'

## gems
#require 'sqlite3'

# local classes
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__)))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'lib'))
require 'mimi_parser'

options = {}
begin
  # set defaults
  options[:csv] = 'pdiff.csv'
  options[:mask] = '*'
  options[:diff] = false

  optparse = OptionParser.new do |opts|
    opts.banner = <<-TXT
Author:
  Craig Chaney
  craig.chaney@mandiant.com

Purpose:
  Parse specified mimikatz files, gather unique creds, and export in
  a CSV file.

Examples:

  pdiff.rb --mask='*mk20*' --dir='tmp' --csv='tmp/example.csv'

Usage: pdiff.rb [options]
    TXT
    opts.on(:OPTIONAL, "--csv", "(Optional) Location of CSV file. Default: 'pdiff.csv'") do |o|
      # set path here as libs are not in same location
      options[:csv] = File.expand_path(o)
    end

    opts.on(:REQUIRED, "--dir", "Directory of mimikatz output for combining") do |o|
      # set path here as libs are not in same location
      options[:dir] = File.expand_path(o)
    end

    mask = <<-MASK
(Optional) Mimikatz output file mask. Default: '*'
        Examples:
          All files - '*'
          All files in starting with 'mimikatz' - 'mimikatz*'
          All files (recursive) - '**/**'
          All files with .txt extension (recursive) - '**/**txt'

    MASK
    opts.on(:OPTIONAL, "--mask", mask) do |o|
      options[:mask] = o
    end

    opts.on(:OPTIONAL, "--diff", "Output new credentials since previous import") do |o|
      options[:diff] = true if o.match(/true/i)
    end

    opts.on_tail("-h", "--help", "Show this message") do
      puts opts
      exit
    end
  end
  optparse.parse!
  # puts options.inspect

  missing = MimiParser.REQUIRED_OPTIONS.select { |param| options[param].nil? }
  if not missing.empty?
    [optparse, "Missing options: #{missing.join(', ')}"].each { |s| puts s; puts }
    exit
  end
  mimi=MimiParser.new(options)
  mimi.run
rescue OptionParser::InvalidOption, OptionParser::MissingArgument
  puts $!.to_s
  puts optparse
  exit
end
