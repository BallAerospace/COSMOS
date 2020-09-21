require 'open-uri'
require 'nokogiri'

class GemsController < ApplicationController
  GEMINABOX_URL = ENV['COSMOS_GEMS_URL'] || ENV['COSMOS_DEVEL'] ? 'http://127.0.0.1:9292' : 'http://cosmos_gems:9292'

  # List the installed gems
  def index
    doc = Nokogiri::XML(URI.open("#{GEMINABOX_URL}/atom.xml"))
    doc.remove_namespaces!
    gems = []
    doc.xpath('//entry/link').each do |a|
      gems << File.basename(a.attributes['href'])
    end
    render :json => gems
  end

  # Add a new gem
  def create
    file = params[:gem]
    if file
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
        if result
          head :ok
        else
          head :internal_server_error
        end
      ensure
        FileUtils.remove_entry(temp_dir) if temp_dir and File.exists?(temp_dir)
      end
    else
      head :internal_server_error
    end
  end

  # Remove a gem
  def destroy
    if params[:gem]
      gem_dot_split = params[:gem].split('.')
      gem_dot_dash_split = gem_dot_split[0].split('-')
      gem_name = gem_dot_dash_split[0..-2].join('-')
      gem_version = [gem_dot_dash_split[-1]].concat(gem_dot_split[1..-2]).join('.')

      STDOUT.puts "Removing gem: #{params[:gem]} (#{gem_name} -v #{gem_version})"

      # Remove gem from geminabox - gem yank my-awesome-gem -v 1.0 --host HOST
      result = false
      thread = Thread.new do
        result = system("gem yank #{gem_name} -v #{gem_version} --host #{GEMINABOX_URL}")
      end
      thread.join
      if result
        head :ok
      else
        head :internal_server_error
      end
    else
      head :internal_server_error
    end
  end
end
