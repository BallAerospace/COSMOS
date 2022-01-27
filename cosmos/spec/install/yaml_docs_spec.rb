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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

require 'spec_helper'
require 'find'
require 'cosmos/system'
require 'cosmos/config/meta_config_parser'

module Cosmos
  describe Cosmos do
    # These are not expected to be documented as they are deprecated
    DEPRECATED = %w(REQUIRE_UTILITY)
    # These source keywords are ignored in the YAML
    EXCEPTIONS = %w(CONVERTED RAW FORMATTED WITH_UNITS NONE WIDGET DYNAMIC)
    EXCEPTIONS.concat(%w(MINUTE HOUR DAY AVG MIN MAX STDDEV AGING CRC OVERRIDE IGNORE_PACKET))

    def process_line(line)
      line.split(',').each do |item|
        item.strip!
        if (item[0] == "'" || item[0] == '"') && (item[-1] == "'" || item[-1] == '"')
          @src_keywords << item[1..-2]
        end
      end
    end

    def process_continuation(line)
      if line[-1] == "\\"
        continuation = true
        line = line[0..-2] # remove the continuation character
      else
        continuation = false
      end
      return continuation
    end

    def get_src_keywords
      @src_keywords = []
      path = File.expand_path(File.join(File.dirname(__FILE__), "../../lib/**/*.rb"))
      Dir[path].each do |filename|
        # There is no longer a system.txt in COSMOS 5 so ignore system_config.rb
        next if File.basename(filename) == 'system_config.rb'

        data = File.read(filename)
        part = nil
        if data.include?('parser.parse_file')
          part = data.split('parser.parse_file')[1..-1].join
        elsif data.include?('handle_config(parser, keyword, parameters)')
          part = data.split('handle_config(parser, keyword, parameters)')[1..-1].join
        end
        if part
          continuation = false
          part.split("\n").each do |line|
            if continuation
              continuation = process_continuation(line)
              process_line(line)
            end
            if match = line.match(/^(?!\s*#)\s*when (.*)/)
              line = match.captures[0]
              continuation = process_continuation(line)
              process_line(line)
            end
          end
        end
      end

      # Get the screen keywords
      path = File.expand_path(File.join(File.dirname(__FILE__), "../../../cosmos-init/plugins/packages/cosmosc2-tool-tlmviewer/src/tools/TlmViewer/CosmosScreen.vue"))
      File.readlines(path).each do |line|
        if match = line.match(/^\s+case '(.*)'/)
          @src_keywords << match.captures[0]
        elsif match = line.match(/keyword.*'(.*)'/)
          @src_keywords << match.captures[0]
        end
      end

      # All the widgets are referenced in screen definitions
      path = File.expand_path(File.join(File.dirname(__FILE__), "../../../cosmos-init/plugins/packages/cosmosc2-tool-common/src/components/widgets/*Widget.vue"))
      Dir[path].each do |filename|
        @src_keywords << filename.split('/')[-1].split('Widget.vue')[0].upcase
      end

      # All the protocols are referenced as keywords in INTERFACES
      path = File.expand_path(File.join(File.dirname(__FILE__), "../../lib/cosmos/interfaces/protocols/*_protocol.rb"))
      Dir[path].each do |filename|
        @src_keywords << filename.split('/')[-1].split('_protocol.rb')[0].upcase
      end

      # Remove things we don't document
      @src_keywords.uniq!
      @src_keywords -= (DEPRECATED + EXCEPTIONS)

      # puts "Total source keywords: #{@src_keywords.length}"
      expect(@src_keywords.length > 100) # Sanity check
    end

    def process_meta(yaml_keywords, meta)
      meta.each do |keyword, data|
        next unless keyword.is_a?(String) && keyword.upcase == keyword
        next if keyword == 'UNKNOWN' # Ignore the UNKNOWN placeholder

        if data['modifiers']
          process_meta(yaml_keywords, data['modifiers'])
        end
        yaml_keywords << keyword
      end
    end

    def get_yaml_keywords
      @yaml_keywords = []
      path = File.expand_path(File.join(File.dirname(__FILE__), "../../data/config/*.yaml"))
      Dir[path].each do |filename|
        # Skip screens and widgets since this is now implemented in Javascript
        # next if filename.include?("screen.yaml") || filename.include?("widgets.yaml")
        meta = Cosmos::MetaConfigParser.load(filename)
        process_meta(@yaml_keywords, meta)
      end
      # puts "Total yaml keywords: #{@yaml_keywords.length}"
      expect(@yaml_keywords.length > 100) # Sanity check
    end

    before(:all) do
      get_src_keywords()
      get_yaml_keywords()
    end

    it "should document all source keywords" do
      undocumented = []
      @src_keywords.each do |keyword|
        undocumented << keyword unless @yaml_keywords.include?(keyword)
      end
      expect(undocumented).to be_empty, "Following source keywords not in YAML: #{undocumented}"
    end

    it "should not have extra keywords" do
      extra = []
      @yaml_keywords.each do |keyword|
        extra << keyword unless @src_keywords.include?(keyword)
      end
      expect(extra).to be_empty, "Following YAML keywords not in source: #{extra}"
    end
  end
end
