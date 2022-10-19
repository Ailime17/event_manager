require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

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

  legislators = legislators_by_zipcode(zipcode)

  personal_letter = erb_template.result(binding)

  save_thank_you_letter(id, personal_letter)
end
