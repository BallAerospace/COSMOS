require 'open-uri'
require 'nokogiri'
require 'httpclient'

module Cosmos
  class GemModel
    GEMINABOX_URL = ENV['COSMOS_GEMS_URL'] || ENV['COSMOS_DEVEL'] ? 'http://127.0.0.1:9292' : 'http://cosmos-gems:9292'

    def self.get(name, dir)
      client = HTTPClient.new(nil)
      path = File.join(dir, name)
      File.open(path, 'wb') do |file|
        file.write(client.get_content("#{GEMINANBOX_URL}/gems/#{name}"))
      end
      return path
    end

    def self.put(file)
      temp_dir = Dir.mktmpdir
      begin
        gem_file_path = temp_dir + '/' + file.original_filename
        FileUtils.cp(file.tempfile.path, gem_file_path)

        STDOUT.puts "Adding gem: #{file.original_filename}"

        # Install gem to geminabox - gem push pkg/my-awesome-gem-1.0.gem --host HOST
        result = false
        thread = Thread.new do
          result = system("gem push #{gem_file_path} --host #{GEMINABOX_URL}")
        end
        thread.join
        return result
      ensure
        FileUtils.remove_entry(temp_dir) if temp_dir and File.exists?(temp_dir)
      end
    end

    def self.destroy(name)
      gem_dot_split = name.split('.')
      gem_dot_dash_split = gem_dot_split[0].split('-')
      gem_name = gem_dot_dash_split[0..-2].join('-')
      gem_version = [gem_dot_dash_split[-1]].concat(gem_dot_split[1..-2]).join('.')

      STDOUT.puts "Removing gem: #{name} (#{gem_name} -v #{gem_version})"

      # Remove gem from geminabox - gem yank my-awesome-gem -v 1.0 --host HOST
      result = false
      thread = Thread.new do
        result = system("gem yank #{gem_name} -v #{gem_version} --host #{GEMINABOX_URL}")
      end
      thread.join
      return result
    end

    def self.names
      doc = Nokogiri::XML(URI.open("#{GEMINABOX_URL}/atom.xml"))
      doc.remove_namespaces!
      gems = []
      doc.xpath('//entry/link').each do |a|
        gems << File.basename(a.attributes['href'])
      end
      gems
    end
  end
end