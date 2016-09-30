# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/ext/config_parser'
require 'tempfile'
require 'erb'

module Cosmos

  # Reads COSMOS style configuration data which consists of keywords followed
  # by 0 or more comma delimited parameters. Parameters with spaces must be
  # enclosed in quotes. Quotes should also be used to indicate a parameter is a
  # string. Keywords are case-insensitive and will be returned in uppercase.
  class ConfigParser
    # @return [String] The current keyword being parsed
    attr_accessor :keyword

    # @return [Array<String>] The parameters found after the keyword
    attr_accessor :parameters

    # @return [String] The name of the configuration file being parsed. This
    #   will be an empty string if the parse_string class method is used.
    attr_accessor :filename

    # @return [String] The current line being parsed. This is the raw string
    #   which is useful when printing errors.
    attr_accessor :line

    # @return [Integer] The current line number being parsed.
    #   This will still be populated when using parse_string because lines
    #   still must be delimited by newline characters.
    attr_accessor :line_number

    # @return [String] The default URL to use in errors. The URL can still be
    #   overridden by directly passing it to the error method.
    attr_accessor :url

    # @see message_callback=
    @@message_callback = nil

    # @param message_callback [#call(String)] Callback method called with a
    #   String when various parsing events occur.
    def self.message_callback=(message_callback)
      @@message_callback = message_callback
    end

    # @see progress_callback=
    @@progress_callback = nil

    # @param progress_callback [#call(Float)] Callback method called with a
    #   Float (0.0 to 100.0) based on the amount of the io param that has
    #   currently been processed.
    def self.progress_callback=(progress_callback)
      @@progress_callback = progress_callback
    end

    # Holds the current splash screen
    @@splash = nil

    # @param splash [Splash::SplashDialogBox] Set the splash dialog box which
    #   will be updated with messages and progress.
    def self.splash=(splash)
      if splash
        @@splash = splash
        @@progress_callback = splash.progress_callback
        @@message_callback = splash.message_callback
      else
        @@splash = nil
        @@progress_callback = nil
        @@message_callback = nil
      end
    end

    # Returns the current splash screen if present
    def self.splash
      @@splash
    end

    # Regular expression used to break up an individual line into a keyword and
    # comma delimited parameters. Handles parameters in single or double quotes.
    PARSING_REGEX = %r{ (?:"(?:[^\\"]|\\.)*") | (?:'(?:[^\\']|\\.)*') | \S+ }x #"

    # Error which gets raised by ConfigParser in #verify_num_parameters. This
    # is also the error that classes using ConfigParser should raise when they
    # encounter a configuration error.
    class Error < StandardError
      attr_reader :keyword, :parameters, :filename, :line, :line_number

      # @return [String] The usage string representing how this keyword should
      #   be formatted.
      attr_reader :usage

      # @return [String] URL which points to usage documentation on the COSMOS
      #   Wiki.
      attr_reader :url

      # Create an Error with the specified Config data
      #
      # @param config_parser [ConfigParser] Instance of ConfigParser so Error
      #   has access to the ConfigParser attributes
      # @param message [String] The error message which gets passed to the
      #   StandardError constructor
      # @param usage [String] The usage string representing how this keyword should
      #   be formatted.
      # @param url [String] URL which should point to usage information. By
      #   default this gets constructed to point to the generic configuration
      #   Guide on the COSMOS Wiki.
      def initialize(config_parser, message = "Configuration Error", usage = "", url = "")
        if Error == message
          super(message.message)
        elsif Exception == message
          super("#{message.class}:#{message.message}")
        else
          super(message)
        end
        @keyword = config_parser.keyword
        @parameters = config_parser.parameters
        @filename = config_parser.filename
        @line = config_parser.line
        @line_number = config_parser.line_number
        @usage = usage
        @url = url
      end
    end

    # @param url [String] The url to link to in error messages
    def initialize(url = "https://github.com/BallAerospace/COSMOS/wiki/Configuration-Guide")
      @url = url
    end

    # Creates an Error
    #
    # @param message [String] The string to set the Exception message to
    # @param usage [String] The usage message
    # @param url [String] Where to get help about this error
    # @return [Error] The constructed error
    def error(message, usage = "", url = @url)
      return Error.new(self, message, usage, url)
    end

    # Called by the ERB template to render a partial
    def render(template_name, options = {})
      b = binding
      if options[:locals]
        options[:locals].each {|key, value| b.local_variable_set(key, value) }
      end
      # Assume the file is there. If not we raise a pretty obvious error
      ERB.new(File.read(File.join(File.dirname(@filename), template_name))).result(b)
    end

    # Processes a file and yields |config| to the given block
    #
    # @param filename [String] The full name and path of the configuration file
    # @param yield_non_keyword_lines [Boolean] Whether to yield all lines including blank
    #   lines or comment lines.
    # @param remove_quotes [Boolean] Whether to remove beginning and ending single
    #   or double quote characters from parameters.
    # @param block [Block] The block to yield to
    # @yieldparam keyword [String] The keyword in the current parsed line
    # @yieldparam parameters [Array<String>] The parameters in the current parsed line
    def parse_file(filename,
                   yield_non_keyword_lines = false,
                   remove_quotes = true,
                   &block)
      @filename = filename
      file = nil
      unparsed_data = nil
      begin
        # Create a temp file where we can write the ERB parsed output
        file = Tempfile.new("parsed_#{File.basename(filename)}")
        unparsed_data = File.read(@filename)
        file.write(ERB.new(unparsed_data).result(binding))
        file.rewind

        size = file.stat.size.to_f

        # Callbacks for beginning of parsing
        @@message_callback.call("Parsing #{size} bytes of #{filename}") if @@message_callback
        @@progress_callback.call(0.0) if @@progress_callback

        # Loop through each line of the data
        parse_loop(file,
                   yield_non_keyword_lines,
                   remove_quotes,
                   size,
                   PARSING_REGEX,
                   &block)
      rescue Exception => e
        debug_file = create_debug_output_file(filename, file, unparsed_data, e)
        if debug_file
          raise e, "#{e}\nDebug output in #{debug_file}", e.backtrace
        else
          raise e
        end
      ensure
        file.close unless file.closed?
      end
    end

    # Verifies the parameters in the config parameter have the specified
    # number of parameter and raises an Error if not.
    #
    # @param [Integer] min_num_params The minimum number of parameters
    # @param [Integer] max_num_params The maximum number of parameters. Pass
    #   nil to indicate there is no maximum number of parameters.
    def verify_num_parameters(min_num_params, max_num_params, usage = "")
      # This syntax works with 0 because each doesn't return any values
      # for a backwards range
      (1..min_num_params).each do |index|
        # If the parameter is nil (0 based) then we have a problem
        if @parameters[index-1].nil?
          raise Error.new(self, "Not enough parameters for #{@keyword}.", usage, @url)
        end
      end
      # If they pass nil for max_params we don't check for a maximum number
      if max_num_params && !@parameters[max_num_params].nil?
        raise Error.new(self, "Too many parameters for #{@keyword}.", usage, @url)
      end
    end

    # Converts a String containing '', 'NIL' or 'NULL' to nil Ruby primitive.
    # All other arguments are simply returned.
    #
    # @param value [Object]
    # @return [nil|Object]
    def self.handle_nil(value)
      if String === value
        case value.upcase
        when '', 'NIL', 'NULL'
          return nil
        end
      end
      return value
    end

    # Converts a String containing 'TRUE' or 'FALSE' to true or false Ruby
    # primitive. All other values are simply returned.
    #
    # @param value [Object]
    # @return [true|false|Object]
    def self.handle_true_false(value)
      if String === value
        case value.upcase
        when 'TRUE'
          return true
        when 'FALSE'
          return false
        end
      end
      return value
    end

    # Converts a String containing '', 'NIL', 'NULL', 'TRUE' or 'FALSE' to nil,
    # true or false Ruby primitives. All other values are simply returned.
    #
    # @param value [Object]
    # @return [true|false|nil|Object]
    def self.handle_true_false_nil(value)
      if String === value
        case value.upcase
        when 'TRUE'
          return true
        when 'FALSE'
          return false
        when '', 'NIL', 'NULL'
          return nil
        end
      end
      return value
    end

    # Converts a string representing a defined constant into its value. The
    # defined constants are the minimum and maximum values for all the
    # allowable data types. [MIN/MAX]_[U]INT[8/16/32] and
    # [MIN/MAX]_FLOAT[32/64]. Thus MIN_UINT8, MAX_INT32, and MIN_FLOAT64 are
    # all allowable values. Any other strings raise ArgumentError but all other
    # types are simply returned.
    #
    # @param value [Object] Can be anything
    # @return [Numeric] The converted value. Either a Fixnum or Float.
    def self.handle_defined_constants(value, data_type = nil, bit_size = nil)
      if value.class == String
        case value.upcase
        when 'MIN', 'MAX'
          return self.calculate_range_value(value.upcase, data_type, bit_size)
        when 'MIN_INT8'
          return -128
        when 'MAX_INT8'
          return 127
        when 'MIN_INT16'
          return -32768
        when 'MAX_INT16'
          return 32767
        when 'MIN_INT32'
          return -2147483648
        when 'MAX_INT32'
          return 2147483647
        when 'MIN_INT64'
          return -9223372036854775808
        when 'MAX_INT64'
          return 9223372036854775807
        when 'MIN_UINT8', 'MIN_UINT16', 'MIN_UINT32', 'MIN_UINT64'
          return 0
        when 'MAX_UINT8'
          return 255
        when 'MAX_UINT16'
          return 65535
        when 'MAX_UINT32'
          return 4294967295
        when 'MAX_UINT64'
          return 18446744073709551615
        when 'MIN_FLOAT64'
          return -Float::MAX
        when 'MAX_FLOAT64'
           return Float::MAX
        when 'MIN_FLOAT32'
          return -3.402823e38
        when 'MAX_FLOAT32'
          return 3.402823e38
        when 'POS_INFINITY'
          return Float::INFINITY
        when 'NEG_INFINITY'
          return -Float::INFINITY
        else
          raise ArgumentError, "Could not convert constant: #{value}"
        end
      end
      return value
    end

    protected

    # Writes the parsed results for debugging if we had an error parsing
    def create_debug_output_file(filename, file, unparsed_data, exception)
      begin
        debug_file = nil
        tmp_folder = File.join(Cosmos::USERPATH, 'outputs', 'tmp')
        tmp_folder = Cosmos::USERPATH unless File.exist?(tmp_folder)
        debug_file = File.join(tmp_folder, "parser_error_#{File.basename(filename)}")
        File.open(debug_file, 'w') do |save_file|
          save_file.puts exception.formatted
          save_file.puts "\nParsed Data (will only be present if parse ran successfully):"
          save_file.puts
          if file
            file.rewind
            save_file.puts file.read
          end
          save_file.puts "\nUnparsed Data:"
          save_file.puts
          save_file.puts unparsed_data if unparsed_data
        end
      rescue Exception
        # Oh well - we tried
        debug_file = nil
      end
      debug_file
    end

    def self.calculate_range_value(type, data_type, bit_size)
      value = 0 # Default for UINT minimum

      case data_type
      when :INT
        if type == 'MIN'
          value = -2**(bit_size-1)
        else # 'MAX'
          value = 2**(bit_size-1) - 1
        end
      when :UINT
        # Default is 0 for 'MIN'
        if type == 'MAX'
          value = 2**bit_size - 1
        end
      when :FLOAT
        case bit_size
        when 32
          value = 3.402823e38
          value *= -1 if type == 'MIN'
        when 64
          value = Float::MAX
          value *= -1 if type == 'MIN'
        else
          raise ArgumentError, "Invalid bit size #{bit_size} for FLOAT type."
        end
      else
        raise ArgumentError, "Invalid data type #{data_type} when calculating range."
      end
      value
    end

    # Iterates over each line of the io object and yields the keyword and
    # parameters
    #~ def parse_loop(
      #~ io,
      #~ yield_non_keyword_lines,
      #~ remove_quotes,
      #~ size,
      #~ rx,
      #~ &block)

  end # class ConfigParser

end # module Cosmos
