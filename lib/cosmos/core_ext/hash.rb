# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# COSMOS specific additions to the Ruby Hash class
class Hash
  # Redefine inspect to only print for small numbers of
  # items.  Prevents exceptions taking forever to be raised with
  # large objects.  See http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-talk/105145
  alias old_inspect inspect

  # @param max_elements [Integer] The maximum number of elements in the Hash to
  #   print out before simply displaying the Hash class and object id
  # @return [String] String representation of the hash
  def inspect(max_elements = 10)
    if self.length <= max_elements
      old_inspect()
    else
      '#<' + self.class.to_s + ':' + self.object_id.to_s + '>'
    end
  end
end
