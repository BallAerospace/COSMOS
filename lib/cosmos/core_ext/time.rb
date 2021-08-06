# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'date'

# This file contains the COSMOS specific additions to the Ruby Time class
#
# Time is expressed in many different ways and with many different epochs.
# This file supports the following formats:
#   Julian Date (jd or julian)
#   Modified Julian Date (mjd)
#   yds (year, day, and seconds of day)
#   mdy (year, month, day, hour, minute, second, us of second)
#   ccsds (day, ms, us from Jan 1, 1958 midnight)
#   time (a ruby time object with unix epoch Jan 1, 1970 midnight)
#   sec (seconds since an arbitrary epoch)
class Time
  # There are 365.25 days per year because of leap years. In the Gregorian
  # calendar some centuries have 36524 days because of the divide by 400 rule
  # while others have 36525 days. The Julian century is DEFINED as having 36525
  # days.
  JULIAN_DAYS_PER_CENTURY     = 36525.0
  # -4713/01/01 Noon
  JULIAN_DATE_OF_JULIAN_EPOCH = 0.0
  # 1858/11/17 Midnight
  JULIAN_DATE_OF_MJD_EPOCH    = 2400000.5
  # 1980/01/06 Midnight
  JULIAN_DATE_OF_GPS_EPOCH    = 2444244.5
  # 2000/01/01 Noon
  JULIAN_DATE_OF_J2000_EPOCH  = 2451545.0
  # 1958/01/01 Midnight
  JULIAN_DATE_OF_CCSDS_EPOCH  = 2436204.5

  DATE_TIME_MJD_EPOCH = DateTime.new(1858, 11, 17)

  USEC_PER_MSEC = 1000
  MSEC_PER_SECOND = 1000
  SEC_PER_MINUTE = 60
  MINUTES_PER_HOUR = 60
  HOURS_PER_DAY = 24
  USEC_PER_SECOND = USEC_PER_MSEC * MSEC_PER_SECOND
  MSEC_PER_MINUTE = 60 * MSEC_PER_SECOND
  MSEC_PER_HOUR = 60 * MSEC_PER_MINUTE
  MSEC_PER_DAY = HOURS_PER_DAY * MSEC_PER_HOUR
  SEC_PER_HOUR = SEC_PER_MINUTE * MINUTES_PER_HOUR
  SEC_PER_DAY = HOURS_PER_DAY * SEC_PER_HOUR
  USEC_PER_DAY = USEC_PER_SECOND * SEC_PER_DAY
  MINUTES_PER_DAY = MINUTES_PER_HOUR * HOURS_PER_DAY

  USEC_PER_MSEC_FLOAT = USEC_PER_MSEC.to_f
  MSEC_PER_SECOND_FLOAT = MSEC_PER_SECOND.to_f
  SEC_PER_MINUTE_FLOAT = SEC_PER_MINUTE.to_f
  MINUTES_PER_HOUR_FLOAT = MINUTES_PER_HOUR.to_f
  HOURS_PER_DAY_FLOAT = HOURS_PER_DAY.to_f
  USEC_PER_SECOND_FLOAT = USEC_PER_SECOND.to_f
  MSEC_PER_MINUTE_FLOAT = MSEC_PER_MINUTE.to_f
  MSEC_PER_HOUR_FLOAT = MSEC_PER_HOUR.to_f
  MSEC_PER_DAY_FLOAT = MSEC_PER_DAY.to_f
  SEC_PER_HOUR_FLOAT = SEC_PER_HOUR.to_f
  SEC_PER_DAY_FLOAT = SEC_PER_DAY.to_f
  USEC_PER_DAY_FLOAT = USEC_PER_DAY.to_f
  MINUTES_PER_DAY_FLOAT = MINUTES_PER_DAY.to_f

  # Class variable that allows us to globally select whether to use
  # UTC or local time.
  @@use_utc = false

  # Set up the Time class so that a call to the sys method will set the
  # Time object being operated upon to be a UTC time.
  def self.use_utc
    @@use_utc = true
  end

  # Set up the Time class so that a call to the sys method will set the
  # Time object being operated upon to be a local time.
  def self.use_local
    @@use_utc = false
  end

  # Set the Time object to be either a UTC or local time depending on the
  # use_utc flag.
  def sys
    if @@use_utc
      self.dup.utc
    else
      self.dup.localtime
    end
  end

  # @param seconds [Numeric] Total number of seconds
  # @return [String] Seconds formatted as a human readable string with days,
  #   hours, minutes, and seconds.
  def self.format_seconds(seconds)
    result = ""
    mm, ss = seconds.divmod(60)
    hh, mm = mm.divmod(60)
    dd, hh = hh.divmod(24)
    if dd != 0
      if dd == 1
        result << "%d day, " % dd
      else
        result << "%d days, " % dd
      end
    end
    if hh != 0
      if hh == 1
        result << "%d hour, " % hh
      else
        result << "%d hours, " % hh
      end
    end
    if mm != 0
      if mm == 1
        result << "%d minute, " % mm
      else
        result << "%d minutes, " % mm
      end
    end
    if ss > 0
      result << "%.2f seconds" % ss
    else
      result = result[0..-3]
    end
    result
  end

  if not defined?(LeapYearMonthDays)
    # The number of days in each month during a leap year
    LeapYearMonthDays = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  end

  if not defined?(CommonYearMonthDays)
    # The number of days in each month during a year (not a leap year)
    CommonYearMonthDays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  end

  # Convert the given year, month, day, hour, minute, second, and us
  # into a Julian date. Julian dates are the number of days (plus fractional
  # days) since Jan 1, 4713 BC at noon.
  #
  # @param year [Integer]
  # @param month [Integer]
  # @param day [Integer]
  # @param hour [Integer]
  # @param minute [Integer]
  # @param second [Integer]
  # @param us [Integer]
  # @return [Float] The given time as a Julian date
  def self.mdy2julian(year, month=1, day=1, hour=0, minute=0, second=0, us=0)
    # Note DateTime does not support fractions of seconds
    date_time = DateTime.new(year, month, day, hour, minute, second)
    (date_time - DATE_TIME_MJD_EPOCH).to_f + JULIAN_DATE_OF_MJD_EPOCH + us / USEC_PER_DAY_FLOAT
  end

  # @return [Float] The Time converted to a julian date
  def to_julian
    return Time.mdy2julian(self.year, self.month, self.day, self.hour, self.min, self.sec, self.usec)
  end
  alias to_jd to_julian

  # Convert the given year, month, day, hour, minute, second, and us
  # into a Modified Julian date. Modified Julian dates have an Epoch of Nov 17,
  # 1858 at midnight.
  #
  # @param year [Integer]
  # @param month [Integer]
  # @param day [Integer]
  # @param hour [Integer]
  # @param minute [Integer]
  # @param second [Integer]
  # @param us [Integer]
  # @return [Time] The given time as a Julian date
  def self.mdy2mjd(year, month=1, day=1, hour=0, minute=0, second=0, us=0)
    return Time.mdy2julian(year, month, day, hour, minute, second, us) - JULIAN_DATE_OF_MJD_EPOCH
  end

  # Convert a time object to the modified julian date
  def to_mjd
    return Time.mdy2mjd(self.year, self.month, self.day, self.hour, self.min, self.sec, self.usec)
  end

  # Create a new time object given year, day of year (1-366), and seconds of day
  #
  # @param year [Integer]
  # @param day_of_year [Integer] (1-366)
  # @param sec_of_day [Integer]
  def self.yds(year, day_of_year, sec_of_day)
    return Time.utc(*yds2mdy(year, day_of_year, sec_of_day))
  end

  # @param year [Integer]
  # @return [Boolean] Whether the year is a leap year
  def self.leap_year?(year)
    return_value = false

    if (year % 4) == 0
      return_value = true

      if (year % 100) == 0
        return_value = false

        if (year % 400) == 0
          return_value = true
        end
      end
    end

    return return_value
  end

  # @return [Boolean] Whether the year is a leap year
  def leap_year?
    Time.leap_year?(self.year)
  end

  # @param hour [Integer]
  # @param minute [Integer]
  # @param second [Integer]
  # @param us [Integer]
  # @return [Float] The number of seconds represented by the hours, minutes,
  #   seconds and microseconds
  def self.total_seconds(hour, minute, second, us)
    (hour * SEC_PER_HOUR_FLOAT) + (minute * SEC_PER_MINUTE_FLOAT) + second + (us / USEC_PER_SECOND_FLOAT)
  end

  # @return [Float] The number of seconds in the day (0-86399.99)
  def seconds_of_day
    Time.total_seconds(self.hour, self.min, self.sec, self.usec)
  end

  # @return [String] Date formatted as YYYY/MM/DD HH:MM:SS.US UTC_OFFSET
  def formatted(include_year = true, fractional_digits = 3, include_utc_offset = false)
    str =  ""
    str << "%Y/%m/%d " if include_year
    str << "%H:%M:%S"
    str << ".%#{fractional_digits}N" if fractional_digits > 0
    if include_utc_offset
      if self.utc?
        str << " UTC"
      else
        str << " %z"
      end
    end
    self.strftime(str)
  end

  # @param time [Time]
  # @return [Float] Number of julian days since Jan 1, 2000 at noon
  def self.days_from_j2000(time)
    time.to_julian - JULIAN_DATE_OF_J2000_EPOCH
  end

  # @param time [Time]
  # @return [Float] Number of julian centuries since Jan 1, 2000 at noon
  def self.julian_centuries_since_j2000(time)
    self.days_from_j2000(time) / JULIAN_DAYS_PER_CENTURY
  end

  # Convert a Julian Date to mdy format
  # Note that an array is returned rather than a Time object because Time objects cannot represent
  # all possible Julian dates
  #
  # @param jdate [Float] Julian date
  # @return [Array<Year, Month, Day, Hour, Minute, Second, Microsecond>] Julian date converted to an array of values
  def self.julian2mdy(jdate)
    z = (jdate + 0.5).to_i
    w = ((z - 1867216.25) / 36524.25).to_i
    x = w / 4
    a = z + 1 + w - x
    b = a + 1524
    c = ((b - 122.1) / 365.25).to_i
    d = (365.25 * c).to_i
    e = ((b - d) / 30.6001).to_i
    f = (30.6001 * e).to_i

    day = b - d - f
    if e > 13
      month = e - 13
    else
      month = e - 1
    end
    if month > 2
      year = c - 4716
    else
      year = c - 4715
    end

    fraction = jdate - jdate.to_i

    if fraction >= 0.5
      hour = (fraction - 0.5) * 24.0
    else
      hour = (fraction * 24.0) + 12.0
    end

    fraction = hour - hour.to_i
    hour = hour.to_i

    minute = fraction * 60.0

    fraction = minute - minute.to_i
    minute = minute.to_i

    second = fraction * 60.0

    fraction = second - second.to_i
    second = second.to_i

    us = fraction * 1000000.0
    us = us.to_i

    return [year, month, day, hour, minute, second, us]
  end

  # Convert a CCSDS Date to mdy format
  # Note that an array is returned rather than a Time object because Time objects cannot represent
  # all possible CCSDS dates
  #
  # @param day [Float] CCSDS day
  # @param ms [Integer] CCSDS milliseconds
  # @param us [Integer] CCSDS microseconds
  # @return [Array<Year, Month, Day, Hour, Minute, Second, Microsecond>] CCSDS date converted to an array of values
  def self.ccsds2mdy(day, ms, us)
    jdate = day + JULIAN_DATE_OF_CCSDS_EPOCH
    year, month, day, hour, minute, second, _ = julian2mdy(jdate)
    hour = (ms / MSEC_PER_HOUR).to_i
    temp = ms - (hour * MSEC_PER_HOUR)
    minute = (temp / MSEC_PER_MINUTE).to_i
    temp -= minute * MSEC_PER_MINUTE
    second = temp / MSEC_PER_SECOND
    temp -= second * MSEC_PER_SECOND
    us = us + (temp * USEC_PER_MSEC)
    return [year, month, day, hour, minute, second, us]
  end

  # Convert from mdy format to CCSDS Date
  # Note that an array is used rather than a Time object because Time objects cannot represent
  # all possible CCSDS dates
  #
  # @param year [Integer]
  # @param month [Integer]
  # @param day [Integer]
  # @param hour [Integer]
  # @param minute [Integer]
  # @param second [Integer]
  # @param us [Integer]
  # @return [Array<day, ms, us>] MDY converted to CCSDS
  def self.mdy2ccsds(year, month, day, hour, minute, second, us)
    ms  = (hour * MSEC_PER_HOUR) + (minute * MSEC_PER_MINUTE) + (second * MSEC_PER_SECOND) + (us / USEC_PER_MSEC)
    us  = us % USEC_PER_MSEC
    jd  = Time.mdy2julian(year, month, day, 0, 0, 0, 0)
    day = (jd - JULIAN_DATE_OF_CCSDS_EPOCH).round
    return [day, ms, us]
  end

  # @param day [Float] CCSDS day
  # @param ms [Integer] CCSDS milliseconds
  # @param us [Integer] CCSDS microseconds
  # @return [Float] The CCSDS date converted to a julian date
  def self.ccsds2julian(day, ms, us)
    (day + JULIAN_DATE_OF_CCSDS_EPOCH) + ((ms.to_f + (us / 1000.0)) / MSEC_PER_DAY_FLOAT)
  end

  # @param jdate [Float] julian date
  # @return [Array<day, ms, us>] Julian converted to CCSDS
  def self.julian2ccsds(jdate)
    day = jdate - JULIAN_DATE_OF_CCSDS_EPOCH
    fraction = day % 1.0
    day = day.to_i
    ms  = fraction * MSEC_PER_DAY_FLOAT
    fraction = ms % 1.0
    ms = ms.to_i
    us = fraction * USEC_PER_MSEC
    us = us.to_i
    return [day, ms, us]
  end

  # @param day [Float] CCSDS day
  # @param ms [Integer] CCSDS milliseconds
  # @param us [Integer] CCSDS microseconds
  # @param sec_epoch_jd [Float] Epoch to convert seconds from as a julian date
  # @return [Float] The number of seconds from the given epoch to the given
  #   CCSDS day, milliseconds, and microseconds.
  def self.ccsds2sec(day, ms, us, sec_epoch_jd = JULIAN_DATE_OF_CCSDS_EPOCH)
    # NOTE: We don't call ccsds2julian to avoid loss of precision
    (day + JULIAN_DATE_OF_CCSDS_EPOCH - sec_epoch_jd +
    ((ms.to_f + (us / 1000.0)) / MSEC_PER_DAY_FLOAT)) * SEC_PER_DAY_FLOAT
  end

  # @param sec [Float] Number of seconds to convert
  # @param sec_epoch_jd [Float] Epoch of seconds value
  # @return [Array<day, ms, us>] CCSDS date
  def self.sec2ccsds(sec, sec_epoch_jd = JULIAN_DATE_OF_CCSDS_EPOCH)
    self.julian2ccsds((sec / SEC_PER_DAY_FLOAT) + sec_epoch_jd)
  end

  # @param year [Integer] Year
  # @param day [Integer] Day of the year
  # @param sec [Float] Seconds in the day
  # @return [Array] [year, month, day, hour, minute, second, usec]
  def self.yds2mdy(year, day, sec)
    # Convert day of year (1-366) to day of month (1-31)
    if self.leap_year?(year)
      array = Time::LeapYearMonthDays
    else
      array = Time::CommonYearMonthDays
    end

    month = 1
    array.each do |days|
      if (day - days) >= 1
        day   -= days
        month += 1
      else
        break
      end
    end

    # Calculate hour of day (0-23)
    hour = (sec / SEC_PER_HOUR).to_i
    sec -= (hour * SEC_PER_HOUR).to_f

    # Calculate minute of hour (0-59)
    min  = (sec / SEC_PER_MINUTE).to_i
    sec -= (min * SEC_PER_MINUTE).to_f

    # Calculate second of minute (0-60)
    seconds = sec.to_i
    sec -= seconds.to_f

    # Calculate useconds of second (0-999999)
    usec = (sec * 1000000.0).to_i

    return [year, month, day, hour, min, seconds, usec]
  end

  # @param year [Integer] Year
  # @param day [Integer] Day of the year
  # @param sec [Integer] Seconds in the day
  # @return [Float] Year, day, seconds converted to the Julian date
  def self.yds2julian(year, day, sec)
    year, month, day, hour, min, seconds, usec = self.yds2mdy(year, day, sec)
    Time.mdy2julian(year, month, day, hour, min, seconds, usec)
  end

  # Ruby time objects cannot handle times before the Unix Epoch.  Calculate a delta (in seconds) to be used
  # when real epochs are before the Unix Epoch.  Each received timestamp will be adjusted by this delta
  # so a ruby time object can be used to parse the time.
  # @param epoch [String] epoch is a string in the following format: "yyyy/mm/dd hh:mm:ss"
  # @return [Float] unix_epohc_delta
  def self.init_epoch_delta(epoch)
    # UnixEpoch - Jan 1, 1970 00:00:00
    unix_epoch = DateTime.new(1970, 1, 1, 0, 0, 0)

    split_epoch = epoch.split
    epoch_date = split_epoch[0].split("/")
    epoch_time = split_epoch[1].split(":")

    if epoch_date[0].to_i < 1970 then
      # Calculate delta between epoch and unix epoch
      real_epoch = DateTime.new(epoch_date[0].to_i, epoch_date[1].to_i, epoch_date[2].to_i, epoch_time[0].to_i, epoch_time[1].to_i, epoch_time[2].to_i)
      day_delta = (unix_epoch - real_epoch).to_i
      unix_epoch_delta = day_delta * 86400
      if real_epoch.hour != 0 or real_epoch.min != 0 or real_epoch.sec != 0
        hour_delta = 23 - real_epoch.hour
        min_delta = 59 - real_epoch.min
        sec_delta = 60 - real_epoch.sec
        unix_epoch_delta += ((hour_delta * 3600) + (min_delta * 60) + sec_delta)
      end
    else
      unix_epoch_delta = 0
    end

    unix_epoch_delta
  end
end
