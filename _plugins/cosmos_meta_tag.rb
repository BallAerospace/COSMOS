require 'erb'

require 'psych'
require 'tempfile'

class Array
  def to_meta_config_yaml(indentation = 0)
    Psych.dump(self).split("\n")[1..-1].join("\n#{' '*indentation}")
  end
end
class Hash
  def to_meta_config_yaml(indentation = 0)
    Psych.dump(self).split("\n")[1..-1].join("\n#{' '*indentation}")
  end
end

module Jekyll
  # Reads YAML formatted files describing a configuration file
  class MetaConfigParser
    class System
      def self.targets
        { 'Any Target Name' => '' }
      end
    end

    def self.load(filename)
      data = nil
      tf = Tempfile.new("temp.yaml")
      cwd = Dir.pwd
      Dir.chdir(File.dirname(filename))
      data = File.read(filename)
      output = ERB.new(data).result(binding)
      tf.write(output)
      tf.close
      begin
        data = Psych.load_file(tf.path)
      rescue => error
        error_file = "ERROR_#{filename}"
        File.open(error_file, 'w') { |file| file.puts output }
        raise error.exception("#{error.message}\n\nParsed output written to #{File.expand_path(error_file)}\n")
      end
      tf.unlink
      Dir.chdir(cwd)
      data
    end

    def self.dump(object, filename)
      File.open(filename, 'w') do |file|
        file.write Psych.dump(object)
      end
    end
  end

  class CosmosMetaTag < Liquid::Tag
    def initialize(tag_name, text, tokens)
      super
      @yaml_file = text
      @modifiers = {}
      @level = 2
    end

    def render(context)
      root = File.expand_path(context.registers[:site].config['cosmos_root']).strip
      path = File.join(root, context.registers[:site].config['cosmos_meta_path'].strip)

      page = ''
      filename = File.join(path, @yaml_file.to_s.strip)
      puts "Processing #{filename}"
      meta = MetaConfigParser.load(filename)
      build_page(meta, page)
      page
    end

    def build_page(meta, page)
      modifiers = {}
      meta.each do |keyword, data|
        page << "\n#{'#' * @level} #{keyword}\n"
        if data['since']
          page << '<div class="right">'
          page <<  "(Since #{data['since']})"
          page << '</div>'
        end
        page << "**#{data['summary']}**\n\n"

        page << "#{data['description']}\n\n" if data['description']
        if data['warning']
          page << '<div class="note warning">'
          page << "<p>#{data['warning']}</p>"
          page << "</div>\n\n"
        end
        if data['parameters']
          page << "| Parameter | Description | Required |\n"
          page << "|-----------|-------------|----------|\n"
          build_parameters(data['parameters'], page)
        end
        if data['example']
          page << "\nExample Usage:\n"
          page << "<figure class=\"highlight\"><pre><code class=\"language-bash\" data-lang=\"bash\">"
          page << "#{data['example'].gsub('<','&lt;').gsub('>','&gt;')}</code></pre></figure>\n"
        end
        modifiers[keyword] = data['modifiers']
      end
      bump_level = false
      modifiers.each do |keyword, modifiers|
        if modifiers
          unless @modifiers.values.include?(modifiers.keys)
            if bump_level == false
              bump_level = true
              @level += 1
            end
            @modifiers[keyword] = modifiers.keys
            page << "\n#{'#' * @level} #{keyword} Modifiers\n"
            page << "The following keywords must follow a #{keyword} keyword.\n"
            build_page(modifiers, page)
          end
        end
      end
    end

    def build_parameters(parameters, page)
      parameters.each do |param|
        description = param['description']
        if param['warning']
          description << '<br/><br/><span class="param_warning">'
          description << "Warning: #{param['warning']}"
          description << "</span>"
        end
        if param['values'].is_a?(Hash)
          description << "<br/><br/>Valid Values: <span class=\"values\">#{param["values"].keys.join(", ")}</span>"
          page << "| #{param['name']} | #{description} | #{param['required'] ? 'True' : 'False'} |\n"
          subparams = {}
          param['values'].each do |keyword, data|
            subparams[data['parameters']] ||= []
            subparams[data['parameters']] << keyword
          end
          # Special key that means we don't traverse subparameters but instead
          # just use the special documentation given
          if param.keys.include?('documentation')
            page << "\n#{param['documentation']}\n"
          else
            subparams.each do |parameters, keywords|
              if parameters
                page << "\nWhen #{param['name']} is #{keywords.join(', ')} the remaining parameters are:\n\n"
                build_parameters(parameters, page)
              end
            end
          end
        elsif param['values'].is_a? Array
          description << "<br/><br/>Valid Values: <span class=\"values\">#{param["values"].join(", ")}</span>"
          page << "| #{param['name']} | #{description} | #{param['required'] ? 'True' : 'False'} |\n"
        else
          page << "| #{param['name']} | #{description} | #{param['required'] ? 'True' : 'False'} |\n"
        end
      end
    end
  end
end

Liquid::Template.register_tag('cosmos_meta', Jekyll::CosmosMetaTag)
