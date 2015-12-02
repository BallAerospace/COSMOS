# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

desc 'Create a picture of gemfile downloads'
task :gemfile_stats do
  require 'gems'
  require 'gruff'

  def get_latest_gem_data
    gem_data = []
    versions = Gems.versions 'cosmos'
    versions.each do |version|
      version_no = version['number']
      month = version['built_at'].split('-')[0..1].join('-')
      gem_data << [month, version_no, Gems.total_downloads("cosmos",version_no)[:version_downloads]] if version_no.split('.')[0] >= '3' # anything before 3 is another gem
    end
    gem_data
  end

  # This is useful for testing to prevent server round trips
  #File.open("gemdata.marshall", 'w') {|file| file.write(Marshal.dump(get_latest_gem_data)) }
  #gem_data = Marshal.load(File.read("gemdata.marshall"))

  gem_data = get_latest_gem_data()
  # Convert all the date text into Ruby Dates
  gem_data.map! {|x| [Date.strptime(x[0], "%Y-%m"), x[1], x[2]]}
  # Sort first by date and then version number
  gem_data.sort_by! {|x| [x[0], x[1]] }
  # Collect all the minor version numbers counts
  new_data = []
  gem_data.each do |date, version, count|
    if version.split('.')[2] == '0'
      new_version = version[0..-2] + 'x'
      new_data << [date, new_version, count]
    else
      new_data[-1][2] += count
    end
  end
  gem_data = new_data

  g = Gruff::StackedArea.new
  g.title = 'COSMOS Downloads'
  labels = {}
  index = 0

  start_date = gem_data[0][0]
  end_date = gem_data[-1][0]
  while (start_date <= end_date)
    labels[index] = start_date.strftime("%Y-%m")
    index += 1
    start_date = start_date >> 1
  end

  dataset = []
  index = 0
  gem_data.each do |date, version, count|
    data = []
    labels.each do |label|
      if date <= Date.strptime(label[1], "%Y-%m")
        data << count
      else
        data << 0
      end
    end
    dataset << [version, data]
  end
  g.labels = labels
  g.marker_font_size = 12
  dataset.each do |data|
    g.data(data[0], data[1])
  end
  g.write('cosmos_downloads.png')
end

