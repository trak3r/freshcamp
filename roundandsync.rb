#!/opt/local/bin/ruby

require 'rubygems'
require 'activesupport' # for X.days.ago
require 'freshbooks'
require 'basecamp'
require 'rounding'
require 'yaml'

TRIGGER = 'synced to Basecamp'

def has_mapped_project?(freshbooks_time_entry)
  @settings['project_mappings'].keys.include?(freshbooks_time_entry.project_id)
end

def already_tagged?(freshbooks_time_entry)
  freshbooks_time_entry.notes.include?(TRIGGER)
end

def is_travel?(freshbooks_time_entry)
  (19 == freshbooks_time_entry.project_id) && (9 == freshbooks_time_entry.task_id)
end

def eligible?(freshbooks_time_entry)
  return false unless has_mapped_project?(freshbooks_time_entry)
  return false if already_tagged?(freshbooks_time_entry)
  return false if is_travel?(freshbooks_time_entry)
  true
end

def xlated_project_id(freshbooks_time_entry)
  @settings['project_mappings'][freshbooks_time_entry.project_id]
end

def log(time_entry)
  @file.puts time_entry.inspect
end

def debugging?
  false
end

def just_rounding?(freshbooks_time_entry)
  1972 == xlated_project_id(freshbooks_time_entry)
end

def save_to_basecamp(basecamp_time_entry)
  if debugging?
    puts "\nSAVING #{basecamp_time_entry.inspect}"
    true
  else
    basecamp_time_entry.save
  end
end

def save_to_freshbooks(freshbooks_record)
  if debugging?
    puts "\nSAVING #{freshbooks_record.inspect}"
    true
  else
    freshbooks_record.create
  end
end

def delete_from_freshbooks(freshbooks_record)
  if debugging?
    puts "\nDELETING #{freshbooks_record.inspect}"
    true
  else
    begin
      freshbooks_record.delete
    rescue Exception => e
      if e.message =~ /Project not found./
        return true # http://forum.freshbooks.com/viewtopic.php?pid=17903
      else
        raise e
      end
    end
  end
end

@settings = YAML::load_file('roundandsync.yaml')

FreshBooks.setup(@settings['freshbooks_domain'], 
                 @settings['freshbooks_api_key'])

Basecamp.establish_connection!(@settings['basecamp_domain'], 
                               @settings['basecamp_username'], 
                               @settings['basecamp_password'],
                               true)

time_entries = FreshBooks::TimeEntry.list(
                'date_from' => (ARGV[0].to_i || 1).days.ago.strftime('%Y-%m-%d'))

@file = File.open(Time.now.strftime("logs/%Y_%m_%d_%M_%S.log"), 'w')

original_total = 0.0
rounded_total = 0.0

time_entries.each do |original_time_entry|
  if eligible?(original_time_entry)
    log(original_time_entry)

    original_time = original_time_entry.hours
    rounded_time = original_time.to_f.round(0.25)
    
    original_total += original_time
    rounded_total += rounded_time

    puts "Rounding #{original_time} to #{rounded_time} for \"#{original_time_entry.notes}\""

    unless just_rounding?(original_time_entry)
      basecamp_time_entry = Basecamp::TimeEntry.new(:project_id => xlated_project_id(original_time_entry))
      basecamp_time_entry.description = "#{original_time_entry.notes} (synced from FreshBooks ID ##{original_time_entry.id})"
      basecamp_time_entry.hours = rounded_time
      basecamp_time_entry.date = original_time_entry.date
      basecamp_time_entry.person_id = @settings['basecamp_person_id']
    end
    
    if just_rounding?(original_time_entry) or save_to_basecamp(basecamp_time_entry)
      new_time_entry = FreshBooks::TimeEntry.new
      new_time_entry.project_id = original_time_entry.project_id
      new_time_entry.task_id = original_time_entry.task_id
      new_time_entry.date = original_time_entry.date
      new_time_entry.hours = rounded_time
      if just_rounding?(original_time_entry)
        new_time_entry.notes = "#{original_time_entry.notes} (#{TRIGGER} #{original_time})"
      else
        new_time_entry.notes = "#{original_time_entry.notes} (rounded from #{original_time} to #{rounded_time} and #{TRIGGER} ID ##{basecamp_time_entry.id})"
      end
    
      if save_to_freshbooks(new_time_entry)
        unless delete_from_freshbooks(original_time_entry)
          puts FreshBooks.last_response.error_msg
        end
      else
        puts FreshBooks.last_response.error_msg
      end
    else
      STDERR.puts "Unable to save to Basecamp; no data modified."
    end

  else
    puts "\nSKIPPING #{original_time_entry.notes}"
  end
end

@file.close

puts "In total rounded #{original_total} hours to #{rounded_total} hours."