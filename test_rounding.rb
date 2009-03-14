#!/opt/local/bin/ruby

require 'rounding'

100.times do
  value = rand
  rounded = value.round(0.25)
  unless 0.0 == rounded % 0.25
    puts "#{value} was erroneously rounded to #{rounded}"
  end
  unless rounded > value
    puts "#{value} was erroneously rounded down to #{rounded}"
  end
  unless rounded < (0.25 + value)
    puts "#{value} was erroneously rounded too high to #{rounded}"
  end
end

unless 3.25 == 3.25.round(0.25)
  puts "Perfectly equal values should not be rounded"
end