require 'cosmos/packets/limits_response'
class LimitsResponse2 < Cosmos::LimitsResponse
  def initialize(val)
    puts "initialize: #{val}"
  end
  def call(target_name, packet_name, item, old_limits_state, new_limits_state)
    puts "#{target_name} #{packet_name} #{item.name} #{old_limits_state} #{new_limits_state}"
  end
end
