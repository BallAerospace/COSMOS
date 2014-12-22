# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# COSMOS specific additions to the Ruby Kernel module
module Kernel
  # @return [Boolean] Whether the current platform is Windows
  def is_windows?
    _, platform, *_ = RUBY_PLATFORM.split("-")
    result = false
    if platform == 'mswin32' or platform == 'mingw32'
      result = true
    end
    return result
  end

  # @return [Boolean] Whether the current platform is Mac
  def is_mac?
    _, platform, *_ = RUBY_PLATFORM.split("-")
    result = false
    if platform =~ /darwin/
      result = true
    end
    return result
  end

  # @param start [Integer] The number of stack entries to skip
  # @return [Symbol] The name of the calling method
  def calling_method(start = 1)
    caller[start][/`([^']*)'/, 1].intern
  end
end
