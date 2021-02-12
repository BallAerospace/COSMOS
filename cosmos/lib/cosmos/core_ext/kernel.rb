# encoding: ascii-8bit

# Copyright 2021 Ball Aerospace & Technologies Corp.
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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

# COSMOS specific additions to the Ruby Kernel module
module Kernel
  # @return [Boolean] Whether the current platform is Windows
  def is_windows?
    Gem.win_platform?
  end

  # @return [Boolean] Whether the current platform is Mac
  def is_mac?
    _, platform, *_ = RUBY_PLATFORM.split("-")
    result = false
    if /darwin/.match?(platform)
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
