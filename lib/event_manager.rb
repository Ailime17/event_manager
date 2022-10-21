require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'
require 'date'

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

def clean_zipcodes(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_homephones(phone_number)
  delimiters = ['.', ' ', "(", ")", "-"]
  phone = phone_number.to_s.split(Regexp.union(delimiters)).join
  if phone.length == 11 && phone.start_with?("1")
    phone[1..]
  elsif phone.length < 10 || phone.length > 10 || !(phone.split("").all? {|i| ('0'..'9').include?(i)})
    'Incorrect Number'
  else
    phone
  end
end

hours_hash = Hash.new(0)
def eval_hours(date, hash)
  the_date = Time.strptime("#{date}", "%m/%e/%y %k:%M")
  hour = the_date.hour
  if hash.key?(hour)
    hash[hour] += 1
  else
    hash[hour] = 1
  end
  hour
end

days_hash = Hash.new(0)
def eval_days(date, hash)
  date_array = Date.strptime("#{date}", "%m/%e/%y %k:%M").to_s.split(" ")
  day = date_array[0]
  day = Date.parse(day)

  numeric_day = day.wday
  english_day_name = day.strftime("%A")

  if hash.key?("#{numeric_day}=(#{english_day_name})")
    hash["#{numeric_day}=(#{english_day_name})"] += 1
  else
    hash["#{numeric_day}=(#{english_day_name})"] = 1
  end
  numeric_day
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'
  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

def save_thank_you_letter(id, personal_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts personal_letter
  end
end

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcodes(row[:zipcode])
  homephone = clean_homephones(row[:homephone])

  reg_hour = eval_hours(row[:regdate], hours_hash)

  reg_day = eval_days(row[:regdate], days_hash)

  legislators = legislators_by_zipcode(zipcode)

  personal_letter = erb_template.result(binding)

  save_thank_you_letter(id, personal_letter)
end

def find_highest_val(hash)
  highest_val_hash = Hash.new(0)
  highest_val_nr = 0
  hash.each do |key, num|
    if num > highest_val_nr
      highest_val_nr = num
      highest_val_hash = Hash.new(0)
      highest_val_hash[key] = num
    end
  end
  hash.each do |key, num|
   highest_val_hash[key] = num if (highest_val_hash.value?(num) && !(highest_val_hash.key?(key)))
  end
  highest_val_hash
end
peak_reg_day = find_highest_val(days_hash)
peak_reg_hours = find_highest_val(hours_hash)
