require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'rubyzip', require: 'zip'
  gem 'lightly'
  gem 'pry'
end

require 'open-uri'

def get_zip_codes
  codes = []
  URI.open('https://download.geonames.org/export/zip/US.zip') do |content|
    Zip::File.open_buffer(content) do |zip|
      zip.each do |entry|
        if entry.name == 'US.txt'
          entry.get_input_stream do |is|
            is.each_line { codes << _1 }
          end
        end
      end
    end
  end

  codes
end

codes = Lightly.get("get_zip_codes") { get_zip_codes }
puts codes.map { _1.split("\t")[4] }.uniq.sort.join(", ")
puts "#{codes.size} entries to be exact"
binding.pry

# google [stream unzip ruby]
# https://stackoverflow.com/questions/33173266/ruby-download-zip-file-and-extract

# https://download.geonames.org/export/zip/
# country code      : iso country code, 2 characters
# postal code       : varchar(20)
# place name        : varchar(180)
# admin name1       : 1. order subdivision (state) varchar(100)
# admin code1       : 1. order subdivision (state) varchar(20)
# admin name2       : 2. order subdivision (county/province) varchar(100)
# admin code2       : 2. order subdivision (county/province) varchar(20)
# admin name3       : 3. order subdivision (community) varchar(100)
# admin code3       : 3. order subdivision (community) varchar(20)
# latitude          : estimated latitude (wgs84)
# longitude         : estimated longitude (wgs84)
# accuracy          : accuracy of lat/lng from 1=estimated, 4=geonameid, 6=centroid of addresses or shape
# US      99553   Akutan  Alaska  AK      Aleutians East  013                     54.143  -165.7854       1


