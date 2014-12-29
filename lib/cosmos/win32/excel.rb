# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'win32ole'

module Cosmos

  #
  # This class will take an Excel spreadsheet and build an easily manipulated spreadsheet in ruby
  #
  class ExcelSpreadsheet

    attr_reader :worksheets

    class ExcelWorksheet

      attr_reader :name, :num_rows, :num_columns, :data

      def initialize (worksheet)
        @name = worksheet.name
        @num_rows = worksheet.UsedRange.rows.count
        @num_columns = worksheet.UsedRange.columns.count

        #Get Excel Data from Worksheet
        @data = worksheet.UsedRange.value
      end

    end

    def initialize (filename)
      excel = WIN32OLE.new('excel.application')
      excel.visible = false
      wb = excel.workbooks.open(filename)

      @worksheets = []

      count = wb.worksheets.count
      count.times do |index|
        ws = wb.worksheets(index + 1)
        @worksheets << ExcelWorksheet.new(ws)
      end

      excel.DisplayAlerts = false
      excel.quit
      excel = nil
      GC.start
    end

  end

  module ExcelColumnConstants
    index = 0
    ('A'..'IV').each do |value|
      self.const_set(value, index)
      index += 1
    end
  end

end # module Cosmos
