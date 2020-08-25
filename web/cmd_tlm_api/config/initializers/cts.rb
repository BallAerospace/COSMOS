require 'cosmos/tools/cmd_tlm_server/cmd_tlm_server'
require 'cosmos/operators/microservice_operator'
$cmd_tlm_server = Cosmos::CmdTlmServer.new
Cosmos::CmdTlmServer.instance.json_drb.object = Cosmos::CmdTlmServer.instance
Thread.new do
  begin
    Cosmos::MicroserviceOperator.run
  rescue Exception => err
    Cosmos::Logger.error("MicroserviceOperator died with Exception\n#{err.formatted}")
  end
end
