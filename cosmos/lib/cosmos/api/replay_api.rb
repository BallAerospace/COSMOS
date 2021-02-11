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

module Cosmos
  module Api
    WHITELIST ||= []
    WHITELIST.concat([
      'replay_select_file',
      'replay_status',
      'replay_set_playback_delay',
      'replay_play',
      'replay_reverse_play',
      'replay_stop',
      'replay_step_forward',
      'replay_step_back',
      'replay_move_start',
      'replay_move_end',
      'replay_move_index',
    ])

    # Select and start analyzing a file for replay
    #
    # filename [String] filename relative to output logs folder or absolute filename
    def replay_select_file(filename, packet_log_reader = "DEFAULT", scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # Get current replay status
    #
    # status, delay, filename, file_start, file_current, file_end, file_index, file_max_index
    def replay_status(scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # Set the replay delay
    #
    # @param delay [Float] delay between packets in seconds 0.0 to 1.0, nil = REALTIME
    def replay_set_playback_delay(delay, scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # Replay start playing forward
    def replay_play(scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # Replay start playing backward
    def replay_reverse_play(scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # Replay stop
    def replay_stop(scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # Replay step forward one packet
    def replay_step_forward(scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # Replay step backward one packet
    def replay_step_back(scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # Replay move to start of file
    def replay_move_start(scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # Replay move to end of file
    def replay_move_end(scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # Replay move to index
    #
    # @param index [Integer] packet index into file
    def replay_move_index(index, scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end
  end
end
