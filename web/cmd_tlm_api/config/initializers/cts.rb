require 'cosmos/tools/cmd_tlm_server/cmd_tlm_server'
require 'cosmos/operators/microservice_operator'
$cmd_tlm_server = Cosmos::CmdTlmServer.new
Cosmos::CmdTlmServer.instance.json_drb.object = Cosmos::CmdTlmServer.instance
Thread.new { Cosmos::MicroserviceOperator.run }
