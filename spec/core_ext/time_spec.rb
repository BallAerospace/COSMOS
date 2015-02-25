# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
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
    it "is correct" do
      Time::JULIAN_DATE_OF_MJD_EPOCH.should eql DateTime.new(1858,11,17).ajd.to_f
      Time::JULIAN_DATE_OF_GPS_EPOCH.should eql DateTime.new(1980,1,06).ajd.to_f
      Time::JULIAN_DATE_OF_J2000_EPOCH.should eql DateTime.new(2000,1,1,12).ajd.to_f
      Time::JULIAN_DATE_OF_CCSDS_EPOCH.should eql DateTime.new(1958,1,1).ajd.to_f
    end
  end

  describe "Time.format_seconds" do
    it "converts a Time to human readable format" do
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
    it "converts year, month, day into a julian date" do
      Time.mdy2julian(1858, 11, 17).should eql Time::JULIAN_DATE_OF_MJD_EPOCH
    end
  end

  describe "to_julian" do
    it "converts a Time into a julian date" do
      Time.new(1858, 11, 17).to_julian.should eql Time::JULIAN_DATE_OF_MJD_EPOCH
    end
  end

  describe "Time.mdy2mjd" do
    it "converts year, month, day into a modified julian date" do
      Time.mdy2mjd(1858, 11, 17).should eql 0.0
    end
  end

  describe "to_mjd" do
    it "converts a Time into a modified julian date" do
      Time.new(1858, 11, 17).to_mjd.should eql 0.0
    end
  end

  describe "Time.yds" do
    it "creates a time based on year, date of year, seconds" do
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
    it "returns true for a leap year" do
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
    it "returns the seconds based on hours, minutes, seconds, us" do
      Time.total_seconds(0,0,0,1000).should eql 0.001
      Time.total_seconds(0,0,1,1000000).should eql 2.0
      Time.total_seconds(0,0,61,0).should eql 61.0
      Time.total_seconds(0,1,61,0).should eql 121.0
      Time.total_seconds(1,1,61,0).should eql 3721.0
      Time.total_seconds(25,0,0,0).should eql 90000.0
    end
  end

  describe "seconds_of_day" do
    it "returns the seconds in the day" do
      Time.new(2020,1,1,1,1,1).seconds_of_day.should eql 3661.0
    end
  end

  describe "formatted" do
    it "formats the Time" do
      Time.new(2020,1,2,3,4,5.5).formatted.should eql "2020/01/02 03:04:05.500"
    end

    it "formats the Time without the date" do
      Time.new(2020,1,2,3,4,5.5).formatted(false).should eql "03:04:05.500"
    end
  end

  describe "Time.days_from_j2000" do
    it "returns the number of days since J2000" do
      Time.days_from_j2000(Time.new(2000,1,1,12)).should eql 0.0
      Time.days_from_j2000(Time.new(2000,1,2,12)).should eql 1.0
    end
  end

  describe "Time.julian_centuries_since_j2000" do
    it "returns the number of centuries since J2000" do
      Time.julian_centuries_since_j2000(Time.new(2100,1,1,12)).should eql 1.0
    end
  end

  describe "Time.julian2mdy" do
    it "returns the YMD from a Julian date" do
      # Result generated from aa.usno.navy.mil/data/docs/JulianDate.php
      # Ignore the seconds value
      Time.julian2mdy(2457024.627836)[0..-2].should eql [2015,1,2,3,4,5]
      # Ignore the seconds value
      Time.julian2mdy(2369916.021181)[0..-2].should eql [1776,7,4,12,30,30]
    end
  end

  describe "Time.ccsds2mdy and Time.mdy2ccsds" do
    it "converts YMD to and from CCSDS" do
      Time.ccsds2mdy(0, 1000, 2).should eql [1958,1,1,0,0,1,2]
      ccsds_day, ccsds_ms, ccsds_us = Time.mdy2ccsds(2015,1,2,3,4,5,6)
      Time.ccsds2mdy(ccsds_day, ccsds_ms, ccsds_us).should eql [2015,1,2,3,4,5,6]
    end
  end

  describe "Time.ccsds2julian and Time.julian2ccsds" do
    it "converts CCSDS to and from Julian" do
      Time.ccsds2julian(0, 1000, 2).should be_within(0.00001).of(2436204.500012)
      time = Time.now
      ccsds_day, ccsds_ms, ccsds_us = Time.mdy2ccsds(2015,1,2,3,4,5,100)
      julian = Time.ccsds2julian(ccsds_day, ccsds_ms, ccsds_us)
      parts = Time.julian2ccsds(julian)
      parts[0].should eql ccsds_day
      parts[1].should eql ccsds_ms
      parts[2].should be_within(50).of(ccsds_us)
    end
  end

  describe "Time.ccsds2sec and Time.sec2ccsds" do
    it "converts seconds to and from CCSDS" do
      Time.ccsds2sec(0, 1000, 2).should be_within(0.00001).of(1)
      time = Time.now
      ccsds_day, ccsds_ms, ccsds_us = Time.mdy2ccsds(2015,1,2,3,4,5,100)
      seconds = Time.ccsds2sec(ccsds_day, ccsds_ms, ccsds_us)
      parts = Time.sec2ccsds(seconds)
      parts[0].should eql ccsds_day
      parts[1].should eql ccsds_ms
      parts[2].should be_within(50).of(ccsds_us)
    end
  end

  describe "Time.yds2mdy" do
    it "converts year, day, seconds" do
      Time.yds2mdy(2020, 1, 1.5).should eql [2020,1,1,0,0,1,500000]
      Time.yds2mdy(2020, 60, 3661.5).should eql [2020,2,29,1,1,1,500000]
      Time.yds2mdy(2021, 60, 3661.5).should eql [2021,3,1,1,1,1,500000]
    end
  end

  describe "Time.yds2julian" do
    it "converts year, day, seconds to julian" do
      Time.yds2julian(2000,1,12*60*60).should eql Time::JULIAN_DATE_OF_J2000_EPOCH
    end
  end

  describe "Time.unix_epoch_delta" do
    it "returns a delta to the unix epoch" do
      Time.init_epoch_delta("1970/01/01 00:00:00").should eql 0
      Time.init_epoch_delta("1969/12/31 12:00:00").should eql 60*60*12
    end
  end
end
