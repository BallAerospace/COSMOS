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

require 'json'
require 'date'

class Object
  def as_json(options = nil) #:nodoc:
    if respond_to?(:to_hash)
      to_hash
    else
      instance_variables
    end
  end
end

class Struct #:nodoc:
  def as_json(options = nil)
    pairs = []
    self.each_pair { |k, v| pairs << k.to_s; pairs << v.as_json(options) }
    Hash[*pairs]
  end
end

class TrueClass
  def as_json(options = nil) self end #:nodoc:
end

class FalseClass
  def as_json(options = nil) self end #:nodoc:
end

class NilClass
  def as_json(options = nil) self end #:nodoc:
end

class String
  NON_ASCII_PRINTABLE = /[^\x21-\x7e\s]/

  def as_json(options = nil)
    if NON_ASCII_PRINTABLE.match?(self)
      self.to_json_raw_object
    else
      self
    end
  end #:nodoc:
end

class Symbol
  def as_json(options = nil) to_s end #:nodoc:
end

class Numeric
  def as_json(options = nil) self end #:nodoc:
end

class Float
  def self.json_create(object)
    case object['raw']
    when "Infinity"  then  Float::INFINITY
    when "-Infinity" then -Float::INFINITY
    when "NaN"       then  Float::NAN
    end
  end

  def as_json(options = nil)
    return { "json_class" => Float, "raw" => "Infinity" }  if self.infinite? ==  1
    return { "json_class" => Float, "raw" => "-Infinity" } if self.infinite? == -1
    return { "json_class" => Float, "raw" => "NaN" }       if self.nan?

    return self
  end
end

class Regexp
  def as_json(options = nil) to_s end #:nodoc:
end

module Enumerable
  def as_json(options = nil) #:nodoc:
    to_a.as_json(options)
  end
end

class Array
  def as_json(options = nil) #:nodoc:
    map { |v| v.as_json(options) }
  end
end

class Hash
  def as_json(options = nil) #:nodoc:
    pairs = []
    self.each { |k, v| pairs << k.to_s; pairs << v.as_json(options) }
    Hash[*pairs]
  end
end

class Time
  def as_json(options = nil) #:nodoc:
    to_json(options).remove_quotes
  end
end

class Date
  def as_json(options = nil) #:nodoc:
    to_json(options).remove_quotes
  end
end

class DateTime
  def as_json(options = nil) #:nodoc:
    to_json(options).remove_quotes
  end
end

class Exception
  def as_json(*a)
    hash = {}
    hash['class'] = self.class.name
    hash['message'] = self.message
    hash['backtrace'] = self.backtrace
    instance_vars = {}
    self.instance_variables.each do |instance_var_name|
      instance_vars[instance_var_name.to_s] = self.instance_variable_get(instance_var_name.to_s.intern)
    end
    hash['instance_variables'] = instance_vars
    hash.as_json(*a)
  end

  def to_json(*a)
    as_json(*a).to_json(*a)
  end

  def self.from_hash(hash)
    begin
      # Get Error class handling namespaced constants
      split_error_class_name = hash['class'].split("::")
      error_class = Object
      split_error_class_name.each do |name|
        error_class = error_class.const_get(name)
      end
    rescue
      error = OpenC3::JsonDRbUnknownError.new(hash['message'])
      error.set_backtrace(hash['backtrace'].concat(caller()))
      raise error
    end
    error = error_class.new(hash['message'])
    error.set_backtrace(hash['backtrace'].concat(caller())) if hash['backtrace']
    hash['instance_variables'].each do |name, value|
      error.instance_variable_set(name.intern, value)
    end
    error
  end
end

module OpenC3
  # An unknown JSON DRb error which can be re-raised by Exception
  class JsonDRbUnknownError < StandardError; end

  # Base class for all JSON Remote Procedure Calls. Provides basic
  # comparison and Hash to JSON conversions.
  class JsonRpc
    include Comparable

    def initialize
      @hash = {}
    end

    # @param other [JsonRpc] Another JsonRpc to compare hash values with
    def <=>(other)
      return nil unless other.respond_to?(:as_json)

      self.as_json(:allow_nan => true) <=> other.as_json(:allow_nan => true)
    end

    # @param a [Array] Array of options
    # @return [Hash] Hash representing the object
    def as_json(*a)
      @hash.as_json(*a)
    end

    # @param a [Array] Array of options
    # @return [String] The JSON encoded String
    def to_json(*a)
      as_json(*a).to_json(*a)
    end
  end

  # Represents a JSON Remote Procedure Call Request
  class JsonRpcRequest < JsonRpc
    DANGEROUS_METHODS = ['__send__', 'send', 'instance_eval', 'instance_exec']

    # @param method_name [String] The name of the method to call
    # @param method_params [Array<String>] Array of strings which represent the
    #   parameters to send to the method
    # @param keyword_params [Hash<String, Variable>] Hash of key value keyword params
    # @param id [Integer] The identifier which will be matched to the response
    def initialize(method_name, method_params, keyword_params, id)
      super()
      @hash['jsonrpc'.freeze] = '2.0'.freeze
      @hash['method'.freeze] = method_name.to_s
      if method_params and method_params.length != 0
        @hash['params'.freeze] = method_params
      end
      if keyword_params and keyword_params.length != 0
        symbolized = {}
        keyword_params.each do |key, value|
          symbolized[key.intern] = value
        end
        @hash['keyword_params'.freeze] = symbolized
      end
      @hash['id'.freeze] = id.to_i
    end

    # @return [String] The method to call
    def method
      @hash['method'.freeze]
    end

    # @return [Array<String>] Array of strings which represent the
    #   parameters to send to the method
    def params
      @hash['params'.freeze] || []
    end

    # @return [Hash<String, Variable>] Hash which represents the
    #   keyword parameters to send to the method
    def keyword_params
      @hash['keyword_params'.freeze]
    end

    # @return [Integer] The request identifier
    def id
      @hash['id'.freeze]
    end

    # Creates a JsonRpcRequest object from a JSON encoded String. The version
    # must be 2.0 and the JSON must include the method and id members.
    #
    # @param request_data [String] JSON encoded string representing the request
    # @param request_headers [Hash] Request Header to include the auth token
    # @return [JsonRpcRequest]
    def self.from_json(request_data, request_headers)
      hash = JSON.parse(request_data, :allow_nan => true, :create_additions => true)
      hash['keyword_params']['token'] = request_headers['HTTP_AUTHORIZATION'] if request_headers['HTTP_AUTHORIZATION']
      # Verify the jsonrpc version is correct and there is a method and id
      raise unless hash['jsonrpc'.freeze] == "2.0".freeze && hash['method'.freeze] && hash['id'.freeze]

      self.from_hash(hash)
    rescue
      raise "Invalid JSON-RPC 2.0 Request\n#{request_data.inspect}\n"
    end

    # Creates a JsonRpcRequest object from a Hash
    #
    # @param hash [Hash] Hash containing the following keys: method, params,
    #   and id
    # @return [JsonRpcRequest]
    def self.from_hash(hash)
      self.new(hash['method'.freeze], hash['params'.freeze], hash['keyword_params'.freeze], hash['id'.freeze])
    end
  end

  # Represents a JSON Remote Procedure Call Response
  class JsonRpcResponse < JsonRpc
    # @param id [Integer] The identifier which will be matched to the request
    def initialize(id)
      super()
      @hash['jsonrpc'.freeze] = "2.0".freeze
      @hash['id'.freeze] = id
    end

    # Creates a JsonRpcResponse object from a JSON encoded String. The version
    # must be 2.0 and the JSON must include the id members. It must also
    # include either result for success or error for failure but never both.
    #
    # @param response_data [String] JSON encoded string representing the response
    # @return [JsonRpcResponse]
    def self.from_json(response_data)
      msg = "Invalid JSON-RPC 2.0 Response#{response_data.inspect}\n"
      begin
        hash = JSON.parse(response_data, :allow_nan => true, :create_additions => true)
      rescue
        raise $!, msg, $!.backtrace
      end

      # Verify the jsonrpc version is correct and there is an ID
      raise msg unless hash['jsonrpc'.freeze] == "2.0".freeze and hash.key?('id'.freeze)

      # If there is a result this is probably a good response
      if hash.key?('result'.freeze)
        # Can't have an error key in a good response
        raise msg if hash.key?('error'.freeze)

        JsonRpcSuccessResponse.from_hash(hash)
      elsif hash.key?('error'.freeze)
        # There was an error key so create an error response
        JsonRpcErrorResponse.from_hash(hash)
      else
        # Neither a result or error key so raise exception
        raise msg
      end
    end
  end

  # Represents a JSON Remote Procedure Call Success Response
  class JsonRpcSuccessResponse < JsonRpcResponse
    # @param id [Integer] The identifier which will be matched to the request
    def initialize(result, id)
      super(id)
      @hash['result'.freeze] = result
    end

    # @return [Object] The result of the method request
    def result
      @hash['result'.freeze]
    end

    # Creates a JsonRpcSuccessResponse object from a Hash
    #
    # @param hash [Hash] Hash containing the following keys: result and id
    # @return [JsonRpcSuccessResponse]
    def self.from_hash(hash)
      self.new(hash['result'.freeze], hash['id'.freeze])
    end
  end

  # Represents a JSON Remote Procedure Call Error Response
  class JsonRpcErrorResponse < JsonRpcResponse
    # @param error [JsonRpcError] The error object
    # @param id [Integer] The identifier which will be matched to the request
    def initialize(error, id)
      super(id)
      @hash['error'.freeze] = error
    end

    # @return [JsonRpcError] The error object
    def error
      @hash['error'.freeze]
    end

    # Creates a JsonRpcErrorResponse object from a Hash
    #
    # @param hash [Hash] Hash containing the following keys: error and id
    # @return [JsonRpcErrorResponse]
    def self.from_hash(hash)
      self.new(JsonRpcError.from_hash(hash['error'.freeze]), hash['id'.freeze])
    end
  end

  # Represents a JSON Remote Procedure Call Error
  class JsonRpcError < JsonRpc
    # Enumeration of JSON RPC error codes
    class ErrorCode
      PARSE_ERROR      = -32700
      INVALID_REQUEST  = -32600
      METHOD_NOT_FOUND = -32601
      INVALID_PARAMS   = -32602
      INTERNAL_ERROR   = -32603
      AUTH_ERROR       = -32500
      FORBIDDEN_ERROR  = -32501
      OTHER_ERROR      = -1
    end

    # @param code [Integer] The error type that occurred
    # @param message [String] A short description of the error
    # @param data [Hash] Additional information about the error
    def initialize(code, message, data = nil)
      super()
      @hash['code'] = code
      @hash['message'] = message
      @hash['data'] = data
    end

    # @return [Integer] The error type that occurred
    def code
      @hash['code']
    end

    # @return [String] A short description of the error
    def message
      @hash['message']
    end

    # @return [Hash] Additional information about the error
    def data
      @hash['data']
    end

    # Creates a JsonRpcError object from a Hash
    #
    # @param hash [Hash] Hash containing the following keys: code, message, and
    #   optionally data
    # @return [JsonRpcError]
    def self.from_hash(hash)
      if hash['code'] and (hash['code'].to_i == hash['code']) and hash['message']
        self.new(hash['code'], hash['message'], hash['data'])
      else
        raise "Invalid JSON-RPC 2.0 Error\n#{hash.inspect}\n"
      end
    end
  end
end
