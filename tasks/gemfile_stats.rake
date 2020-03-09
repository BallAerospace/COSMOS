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
  require 'win32ole'

  def get_latest_gem_data
    gem_data = []
    # This is the only API call to Rubygems
    versions = Gems.versions 'cosmos'
    versions.each do |version|
      version_no = version['number']
      next if version_no.split('.')[0] < '3' # anything before 3 is another gem
      month = version['built_at'].split('-')[0..1].join('-')
      downloads = version['downloads_count'].to_i
      if gem_data.length > 0 && gem_data[-1][1] == version_no
        gem_data[-1][2] += downloads
      else
        gem_data << [month, version_no, downloads]
      end
    end
    gem_data
  end

  # This is useful for testing to prevent server round trips
  # Simply comment out this line when working on the formatting below (after first running once)
  File.open("gemdata.marshall", 'w') {|file| file.write(Marshal.dump(get_latest_gem_data())) }
  gem_data = Marshal.load(File.read("gemdata.marshall"))

  # Convert all the date text into Ruby Dates
  gem_data.map! {|x| [Date.strptime(x[0], "%Y-%m"), x[1], x[2]]}
  # Sort first by date and then version number
  gem_data.sort_by! {|x| [x[0], x[1]] }

  excel = WIN32OLE.new('excel.application')
  excel.visible = true
  book = excel.Workbooks.Add
  sheet = book.Worksheets(1)

  # Build up date labels
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

  # Put dates in rows as there are more dates than there are releases
  # Force the date column to be text
  sheet.Columns(1).NumberFormat = "\@"
  labels.values.each_with_index do |val, x|
    sheet.Cells((x+2), 1).Value = val
  end

  col = 2
  dataset.each do |version, data|
    # Set the version (e.g. 3.0) in the top row
    sheet.Cells(1, col).Value = version
    # The download values by date appear below the version in the same column
    data.each_with_index do |val, x|
      sheet.Cells((x+2), col).Value = val
    end
    col += 1
  end
  # Excel column name lookup, 4 sets of alphabets gives us 104 versions to work with
  letters = ('A'..'Z').to_a.concat(('AA'..'AZ').to_a).concat(('BA'..'BZ').to_a).concat(('CA'..'CZ').to_a)
  chart = book.Charts.Add
  chart.Name = "COSMOS Downloads"
  chart.SetSourceData(sheet.Range("A1:#{letters[dataset.length]}#{labels.length+1}"))
  chart.HasTitle = true
  chart.ChartTitle.Characters.Text = "COSMOS Downloads"
  chart.ChartType = 76 # AreaStacked
end
