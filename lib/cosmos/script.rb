# encoding: ascii-8bit

# Enforce not allowing this file to be included within CmdTlmServer
# TODO: This checks needs to be updated for COSMOS 5
if $0 =~ /CmdTlmServer/ or $0 =~ /Replay/
  raise "cosmos/script must not be required by any code used in the CmdTlmServer or Replay applications"
end

require 'cosmos/script/script'
include Cosmos::Script
