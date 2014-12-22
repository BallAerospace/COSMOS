# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# COSMOS specific additions to the Ruby Range class
class Range
  # @return [Array<Float>] Array of each value within the Range converted to
  #   Float
  def to_a_to_f
    array = []
    self.each do |value|
      array << value.to_f
    end
    array
  end
end
