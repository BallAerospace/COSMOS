module Jekyll
  # Call the COSMOS tool with the --help option and record the command line parameters
  # which go into the webpage wrapped in a code block
  class CosmosCmdLineTag < Liquid::Tag
    def initialize(tag_name, text, tokens)
      super
      @command = text
    end

    def render(context)
      path = File.expand_path(context.registers[:site].config['cosmos_tool_path'].to_s.clone).strip
      page = ''
      output = ''
      Bundler.with_clean_env do
        Dir.chdir(path) do
          output = `bundle exec ruby #{@command} --help`
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
