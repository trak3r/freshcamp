#!/opt/local/bin/ruby

require 'rubygems'
require 'activesupport' # for X.days.ago
require 'freshbooks'
require 'basecamp'
require 'rounding'
require 'yaml'

TRIGGER = 'synced to Basecamp'

def eligible?(freshbooks_time_entry)
  return false unless @settings['project_mappings'].keys.include?(freshbooks_time_entry.project_id)
  return false if freshbooks_time_entry.notes.include?(TRIGGER)
  true
end

def xlated_project_id(freshbooks_time_entry)
  @settings['project_mappings'][freshbooks_time_entry.project_id]
end

def log(time_entry)
  @file.puts time_entry.inspect
end

@settings = YAML::load_file('roundandsync.yaml')

FreshBooks.setup(@settings['freshbooks_domain'], 
                 @settings['freshbooks_api_key'])

Basecamp.establish_connection!(@settings['basecamp_domain'], 
                               @settings['basecamp_username'], 
                               @settings['basecamp_username'])

time_entries = FreshBooks::TimeEntry.list(
                'date_from' => 3.days.ago.strftime('%Y-%m-%d'))

@file = File.open(Time.now.strftime("%Y_%m_%d_%M_%S.log"), 'w')

time_entries.each do |original_time_entry|
  if eligible?(original_time_entry)
    log(original_time_entry)

    original_time = original_time_entry.hours
    rounded_time = original_time.to_f.round(0.25)

    puts "Rounding #{original_time} to #{rounded_time} for \"#{original_time_entry.notes}\""

    basecamp_time_entry = Basecamp::TimeEntry.new
    basecamp_time_entry.project_id = xlated_project_id(original_time_entry)
    basecamp_time_entry.body = "#{original_time_entry.notes} (synced from FreshBooks ID ##{original_time_entry.id})"
    basecamp_time_entry.hours = rounded_time
    
    # if basecamp_time_entry.save
    #   new_time_entry = FreshBooks::TimeEntry.new
    #   new_time_entry.project_id = original_time_entry.project_id
    #   new_time_entry.task_id = original_time_entry.task_id
    #   new_time_entry.date = original_time_entry.date
    #   new_time_entry.notes = "#{original_time_entry.notes} (rounded from #{original_time} to #{rounded_time} and #{TRIGGER} ID ##{basecamp_time_entry.id})"
    #   new_time_entry.hours = rounded_time
    # 
    #   if new_time_entry.create
    #     unless original_time_entry.delete
    #       puts FreshBooks.last_response.error_msg
    #     end
    #   else
    #     puts FreshBooks.last_response.error_msg
    #   end
    # else
    #   STDERR.puts "Unable to save to Basecamp"
    # end

  else
    puts "Skipping #{original_time_entry.notes}"
  end
end

@file.close
