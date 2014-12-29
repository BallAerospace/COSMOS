# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos

  module LayoutWidget

    module ClassMethods
      def layout_manager?
        return true
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    # This gets called when the layout gets closed by the END keyword
    # Subclasses can implement this to do things once all their child
    # widgets have been created.
    def complete
      # Normally do nothing
    end

  end

end # module Cosmos
