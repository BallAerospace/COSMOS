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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

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
