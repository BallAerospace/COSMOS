
require 'spec_helper'
require 'find'
require 'cosmos/system'
require 'cosmos/config/meta_config_parser'

module Cosmos
  describe Cosmos do
    # These are not expected to be documented as they are deprecated
    DEPRECATED = %w(MACRO_APPEND_START MACRO_APPEND_END ROUTER_LOG_RAW IGNORE REQUIRE_UTILITY)
    # These source keywords are ignored in the YAML
    EXCEPTIONS = %w(LAUNCH LAUNCH_TERMINAL LAUNCH_GEM CONVERTED RAW FORMATTED WITH_UNITS NONE)
    EXCEPTIONS.concat(%w(MINUTE HOUR DAY AVG MIN MAX STDDEV AGING CRC OVERRIDE))
    # These are not documented because OpenGL is not officially a tool
    OPENGL = %w(STL_FILE TEXTURE_MAPPED_SPHERE TIP_TEXT POSITION ROTATION_X ROTATION_Y ROTATION_Z)
    OPENGL.concat(%w(ZOOM ORIENTATION CENTER BOUNDS))

    def get_src_keywords
      @src_keywords = []
      path = File.expand_path(File.join(File.dirname(__FILE__), "../../lib/**/*.rb"))
      Dir[path].each do |filename|
        data = File.read(filename)
        part = nil
        if data.include?('parser.parse_file')
          part = data.split('parser.parse_file')[1..-1].join
        elsif data.include?('handle_keyword(parser, keyword, parameters)')
          part = data.split('handle_keyword(parser, keyword, parameters)')[1..-1].join
        end
        if part
          part.split("\n").each do |line|
            if match = line.match(/when (.*)/)
              line = match.captures[0]
              line.split(',').each do |item|
                item.strip!
                if (item[0] == "'" || item[0] == '"') && (item[-1] == "'" || item[-1] == '"')
                  @src_keywords << item[1..-2]
                end
              end
            end
          end
        end
      end

      # All the widgets are referenced in screen definitions
      path = File.expand_path(File.join(File.dirname(__FILE__), "../../lib/cosmos/tools/tlm_viewer/widgets/*_widget.rb"))
      Dir[path].each do |filename|
        @src_keywords << filename.split('/')[-1].split('_widget.rb')[0].upcase
      end
      # Remove the base classes
      @src_keywords -= %w(CANVASVALUE LAYOUT MULTI)
      # Add specific keyword(s) that we want to document
      @src_keywords.concat(%w(NAMED_WIDGET))

      # All the protocols are referenced as keywords in INTERFACES
      path = File.expand_path(File.join(File.dirname(__FILE__), "../../lib/cosmos/interfaces/protocols/*_protocol.rb"))
      Dir[path].each do |filename|
        @src_keywords << filename.split('/')[-1].split('_protocol.rb')[0].upcase
      end

      # Remove things we don't document
      @src_keywords.uniq!
      @src_keywords -= (DEPRECATED + EXCEPTIONS + OPENGL)

      #puts "Total source keywords: #{@src_keywords.length}"
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
        meta = Cosmos::MetaConfigParser.load(filename)
        process_meta(@yaml_keywords, meta)
      end
      #puts "Total yaml keywords: #{@yaml_keywords.length}"
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
