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

  g = Gruff::StackedArea.new
  g.title = 'COSMOS Downloads'

  # Build up date labels on the bottom of the graph
  labels = {} # Must be hash with integer keys and label value
  index = 0
  start_date = gem_data[0][0]
  end_date = gem_data[-1][0]
  while (start_date <= end_date)
    labels[index] = start_date.strftime("%m/%y")
    index += 1
    start_date = start_date >> 1
  end

  # Create an array of 0s the size of the labels which will hold the D/L counts
  counts = Array.new(labels.length, 0)
  dataset = {}
  gem_data.each do |full_date, full_version, count|
    # Build up just the major minor version: 1.0
    version = full_version.split('.')[0..1].join('.')
    date = full_date.strftime("%m/%y")
    # Find the location in the count array to start adding counts
    index = labels.key(date)
    dataset[version] ||= counts.clone
    # We fill in the count array starting at the first location
    # and going until the end because this is a stacked area graph
    # and all the counts are additive over time
    (index...counts.length).each do |i|
      dataset[version][i] += count
    end
  end

  g.labels = labels
  g.marker_font_size = 12
  dataset.each do |version, data|
    g.data(version, data)
  end
  g.write('cosmos_downloads.png')
end

