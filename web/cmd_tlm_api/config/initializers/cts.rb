require 'cosmos/api/authorized_api'
require 'cosmos/io/json_drb'

module Cosmos
  class Cts
    include AuthorizedApi

    attr_accessor :json_drb

    @@instance = nil

    def initialize
      @json_drb = JsonDRb.new
      @json_drb.method_whitelist = Api::WHITELIST
      @json_drb.object = self
    end

    def self.instance
      @@instance ||= new()
    end
  end
end

Cosmos::Cts.instance
