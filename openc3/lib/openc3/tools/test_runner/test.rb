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

require 'openc3/script/suite'
require 'openc3/script/exceptions'

module OpenC3
  # @deprecated Use SkipScript
  class SkipTestCase < SkipScript; end

  # @deprecated Use Suite
  class TestSuite < Suite
    alias :tests :scripts
    alias :add_test :add_group
    alias :add_test_case :add_script
    alias :add_test_setup :add_group_setup
    alias :add_test_teardown :add_group_teardown
    alias :run_test :run_group
    alias :run_test_case :run_script
    alias :get_num_test :get_num_scripts
    alias :run_test_setup :run_group_setup
    alias :run_test_teardown :run_group_teardown
  end

  # @deprecated Use Group
  class Test < Group
    alias :run_test_case :run_script

    class << self
      alias :test_cases :scripts
      alias :get_num_tests :get_num_scripts
      alias :current_test_suite :current_suite
      alias :current_test_group :current_group
      alias :current_test :current_group
      alias :current_test_case :current_script
    end
  end

  # @deprecated Use ScriptStatus
  class TestStatus < ScriptStatus; end

  # @deprecated Use ScriptResult
  class TestResult < ScriptResult
    alias :test_suite :suite
    alias :test_suite= :suite=
    alias :test :group
    alias :test= :group=
    alias :test_case :script
    alias :test_case= :script=
  end
end
