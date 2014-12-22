# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/ext/array'

# COSMOS specific additions to the ObjectSpace class
module ObjectSpace
  def self.find(klass)
    ObjectSpace.each_object(klass) do |object|
      return object
    end
    nil
  end

  def self.find_all(klass)
    objects = []
    ObjectSpace.each_object(klass) do |object|
      objects << object
    end
    objects
  end
end # class ObjectSpace
