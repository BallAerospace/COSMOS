# encoding: ascii-8bit

# Copyright 2022 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved

# OpenC3 specific additions to the Ruby Exception class
class Exception
  # @param hide_runtime_error_class [Boolean] Whether to hide the Exception
  #   error class if the class is RuntimeError. Other classes will continue to
  #   be printed.
  # @param include_backtrace [Boolean] Whether to include the full exception
  #   backtrace
  # @return [String] The formatted Exception
  def formatted(hide_runtime_error_class = false, include_backtrace = true)
    if include_backtrace and self.backtrace
      if hide_runtime_error_class and self.class == RuntimeError
        "#{self.message}\n#{self.backtrace.join("\n")}"
      else
        "#{self.class.to_s.split('::')[-1]} : #{self.message}\n#{self.backtrace.join("\n")}"
      end
    else
      if hide_runtime_error_class and self.class == RuntimeError
        "#{self.message}"
      else
        "#{self.class.to_s.split('::')[-1]} : #{self.message}"
      end
    end
  end

  # @return [Array(String, Fixnum)] The filename and line number where the Exception
  #   occurred
  def source
    trace = self.backtrace[0]
    split_trace = trace.split(':')
    filename = ''
    line_number = ''
    if trace[1..1] == ':' # Windows Path
      filename = split_trace[0] + ':' + split_trace[1]
      line_number = split_trace[2].to_i
    else
      filename = split_trace[0]
      line_number = split_trace[1].to_i
    end

    [filename, line_number]
  end
end
