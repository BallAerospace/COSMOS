# encoding: ascii-8bit

module Cosmos
  autoload(:Interface, 'cosmos/interfaces/interface.rb')
  autoload(:StreamInterface, 'cosmos/interfaces/stream_interface.rb')
  autoload(:SerialInterface, 'cosmos/interfaces/serial_interface.rb')
  autoload(:SimulatedTargetInterface, 'cosmos/interfaces/simulated_target_interface.rb')
  autoload(:TcpipClientInterface, 'cosmos/interfaces/tcpip_client_interface.rb')
  autoload(:TcpipServerInterface, 'cosmos/interfaces/tcpip_server_interface.rb')
  autoload(:UdpInterface, 'cosmos/interfaces/udp_interface.rb')
  autoload(:LincInterface, 'cosmos/interfaces/linc_interface.rb')
  autoload(:LincHandshakeCommand, 'cosmos/interfaces/linc_interface.rb')
  autoload(:LincHandshake, 'cosmos/interfaces/linc_interface.rb')
  autoload(:DartStatusInterface, 'cosmos/interfaces/dart_status_interface.rb')

  autoload(:Protocol, 'cosmos/interfaces/protocols/protocol.rb')
  autoload(:BurstProtocol, 'cosmos/interfaces/protocols/burst_protocol.rb')
  autoload(:FixedProtocol, 'cosmos/interfaces/protocols/fixed_protocol.rb')
  autoload(:LengthProtocol, 'cosmos/interfaces/protocols/length_protocol.rb')
  autoload(:PreidentifiedProtocol, 'cosmos/interfaces/protocols/preidentified_protocol.rb')
  autoload(:TemplateProtocol, 'cosmos/interfaces/protocols/template_protocol.rb')
  autoload(:TerminatedProtocol, 'cosmos/interfaces/protocols/terminated_protocol.rb')

  autoload(:OverrideProtocol, 'cosmos/interfaces/protocols/override_protocol.rb')
  autoload(:CrcProtocol, 'cosmos/interfaces/protocols/crc_protocol.rb')
  autoload(:IgnorePacketProtocol, 'cosmos/interfaces/protocols/ignore_packet_protocol.rb')
end
