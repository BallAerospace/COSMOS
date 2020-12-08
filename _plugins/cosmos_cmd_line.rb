module Jekyll
  # Call the COSMOS tool with the --help option and record the command line parameters
  # which go into the webpage wrapped in a code block
  class CosmosCmdLineTag < Liquid::Tag
    def initialize(tag_name, text, tokens)
      super
      @command = text
    end

    def render(context)
      root = File.expand_path(context.registers[:site].config['cosmos_root']).strip
      path = context.registers[:site].config['cosmos_tool_path'].strip
      output = ''
      page = ''
      Bundler.with_unbundled_env do
        Dir.chdir(root) do
          puts "Getting cmd line for #{File.join(path, @command)}"
          output = `bundle exec ruby #{File.join(path, @command)} --help`
        end
      end
      build_page(output, page)
      page
    end

    def build_page(output, page)
      page << "\n## Command Line Parameters\n"
      page << "```\n#{output}```\n"
    end
  end
end

Liquid::Template.register_tag('cosmos_cmd_line', Jekyll::CosmosCmdLineTag)
