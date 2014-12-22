# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/core_ext/time'

describe Time do

  describe "CONSTANTS" do
    it "should be correct" do
      Time::JULIAN_DATE_OF_MJD_EPOCH.should eql DateTime.new(1858,11,17).ajd.to_f
      Time::JULIAN_DATE_OF_GPS_EPOCH.should eql DateTime.new(1980,1,06).ajd.to_f
      Time::JULIAN_DATE_OF_J2000_EPOCH.should eql DateTime.new(2000,1,1,12).ajd.to_f
      Time::JULIAN_DATE_OF_CCSDS_EPOCH.should eql DateTime.new(1958,1,1).ajd.to_f
    end
  end

  describe "Time.format_seconds" do
    it "should convert a Time to human readable format" do
      Time.format_seconds(1).should eql "1.00 seconds"
      Time.format_seconds(1.2345).should eql "1.23 seconds"
      Time.format_seconds(60).should eql "1 minute"
      Time.format_seconds(121).should eql "2 minutes, 1.00 seconds"
      Time.format_seconds(3600).should eql "1 hour"
      Time.format_seconds(7201).should eql "2 hours, 1.00 seconds"
      Time.format_seconds(7261).should eql "2 hours, 1 minute, 1.00 seconds"
      Time.format_seconds(3600*24).should eql "1 day"
      Time.format_seconds(3600*24+1).should eql "1 day, 1.00 seconds"
      Time.format_seconds(3600*48+61).should eql "2 days, 1 minute, 1.00 seconds"
      Time.format_seconds(3600*25+61).should eql "1 day, 1 hour, 1 minute, 1.00 seconds"
    end
  end

  describe "Time.mdy2julian" do
    it "should convert year, month, day into a julian date" do
      Time.mdy2julian(1858, 11, 17).should eql Time::JULIAN_DATE_OF_MJD_EPOCH
    end
  end

  describe "to_julian" do
    it "should convert a Time into a julian date" do
      Time.new(1858, 11, 17).to_julian.should eql Time::JULIAN_DATE_OF_MJD_EPOCH
    end
  end

  describe "Time.mdy2mjd" do
    it "should convert year, month, day into a modified julian date" do
      Time.mdy2mjd(1858, 11, 17).should eql 0.0
    end
  end

  describe "to_mjd" do
    it "should convert a Time into a modified julian date" do
      Time.new(1858, 11, 17).to_mjd.should eql 0.0
    end
  end

  describe "Time.yds" do
    it "should create a time based on year, date of year, seconds" do
      time = Time.yds(2020, 1, 1)
      time.year.should eql 2020
      time.month.should eql 1
      time.day.should eql 1
      time.hour.should eql 0
      time.min.should eql 0
      time.sec.should eql 1

      time = Time.yds(2020, 366, 7261)
      time.year.should eql 2020
      time.month.should eql 12
      time.day.should eql 31
      time.hour.should eql 2
      time.min.should eql 1
      time.sec.should eql 1
    end
  end

  describe "Time.leap_year?" do
    it "should return true for a leap year" do
      expect(Time.leap_year?(2020)).to be true
      expect(Time.leap_year?(2021)).to be false
    end
  end

  describe "leap_year?" do it "should return true for a leap year" do
      expect(Time.new(2020).leap_year?).to be true
      expect(Time.new(2021).leap_year?).to be false
    end
  end

  describe "Time.total_seconds" do
    it "should return the seconds based on hours, minutes, seconds, us" do
      Time.total_seconds(0,0,0,1000).should eql 0.001
      Time.total_seconds(0,0,1,1000000).should eql 2.0
      Time.total_seconds(0,0,61,0).should eql 61.0
      Time.total_seconds(0,1,61,0).should eql 121.0
      Time.total_seconds(1,1,61,0).should eql 3721.0
      Time.total_seconds(25,0,0,0).should eql 90000.0
    end
  end

  describe "seconds_of_day" do
    it "should return the seconds in the day" do
      Time.new(2020,1,1,1,1,1).seconds_of_day.should eql 3661.0
    end
  end

  describe "formatted" do
    it "should format the Time" do
      Time.new(2020,1,2,3,4,5.5).formatted.should eql "2020/01/02 03:04:05.500"
    end

    it "should format the Time without the date" do
      Time.new(2020,1,2,3,4,5.5).formatted(false).should eql "03:04:05.500"
    end
  end

  describe "Time.days_from_j2000" do
    it "should return the number of days since J2000" do
      Time.days_from_j2000(Time.new(2000,1,1,12)).should eql 0.0
      Time.days_from_j2000(Time.new(2000,1,2,12)).should eql 1.0
    end
  end

  describe "Time.julian_centuries_since_j2000" do
    it "should return the number of centuries since J2000" do
      Time.julian_centuries_since_j2000(Time.new(2100,1,1,12)).should eql 1.0
    end
  end

  describe "Time.yds2mdy" do
    it "should convert year, day, seconds" do
      Time.yds2mdy(2020, 1, 1.5).should eql [2020,1,1,0,0,1,500000]
      Time.yds2mdy(2020, 60, 3661.5).should eql [2020,2,29,1,1,1,500000]
      Time.yds2mdy(2021, 60, 3661.5).should eql [2021,3,1,1,1,1,500000]
    end
  end

  describe "Time.yds2julian" do
    it "should convert year, day, seconds to julian" do
      Time.yds2julian(2000,1,12*60*60).should eql Time::JULIAN_DATE_OF_J2000_EPOCH
    end
  end
end
