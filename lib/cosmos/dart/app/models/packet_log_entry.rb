class PacketLogEntry < ApplicationRecord
  NOT_STARTED = 0
  IN_PROGRESS = 1
  COMPLETE = 2
  NO_CONFIG = 3
  NO_PACKET = 4
  NO_META_PLE = 5
  NO_META_PACKET = 6
  NO_SYSTEM_CONFIG = 7
  NO_PACKET_CONFIG = 8

  def decom_state_string
    case self.decom_state
    when NOT_STARTED
      'NOT_STARTED'
    when IN_PROGRESS
      'IN_PROGRESS'
    when COMPLETE
      'COMPLETE'
    when NO_CONFIG
      'NO_CONFIG'
    when NO_PACKET
      'NO_PACKET'
    when NO_META_PLE
      'NO_META_PLE'
    when NO_META_PACKET
      'NO_META_PACKET'
    when NO_SYSTEM_CONFIG
      'NO_SYSTEM_CONFIG'
    when NO_PACKET_CONFIG
      'NO_PACKET_CONFIG'
    else
      'UNKNOWN'
    end
  end

end
