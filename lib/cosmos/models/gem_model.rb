# encoding: ascii-8bit

# Copyright 2021 Ball Aerospace & Technologies Corp.
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

require 'open-uri'
require 'nokogiri'
require 'httpclient'

module Cosmos
  # Abstracts interacting with the the local gem server (geminabox).
  # This class acts like a Model but doesn't inherit from Model because it doesn't
  # actual interact with the Store (Redis). Instead we implement names, get, put
  # and destroy to allow interaction with the gem server from the PluginModel and
  # the GemsController.
  class GemModel
    GEMINABOX_URL = ENV['COSMOS_GEMS_URL'] || (ENV['COSMOS_DEVEL'] ? 'http://127.0.0.1:9292' : 'http://cosmos-gems:9292')

    def self.names
      doc = Nokogiri::XML(URI.open("#{GEMINABOX_URL}/atom.xml"))
      doc.remove_namespaces!
      gems = []
      doc.xpath('//entry/link').each do |a|
        gems << File.basename(a.attributes['href'])
      end
      gems
    end

    def self.get(dir, name)
      path = File.join(dir, name)
      File.open(path, 'wb') do |file|
        file.write(HTTPClient.get_content("#{GEMINABOX_URL}/gems/#{name}"))
      end
      return path
    end

    def self.put(gem_file_path)
      if File.file?(gem_file_path)
        # Install gem to geminabox - gem push pkg/my-awesome-gem-1.0.gem --host HOST
        command = "gem inabox #{gem_file_path} --host #{GEMINABOX_URL}"
        Logger.info "Installing gem: #{command}"
        return run_command(command)
      else
        message = "Gem file #{gem_file_path} does not exist!"
        Logger.error message
        raise message
      end
    end

    def self.destroy(name)
      gem_dot_split = name.split('.')
      gem_dot_dash_split = gem_dot_split[0].split('-')
      gem_name = gem_dot_dash_split[0..-2].join('-')
      gem_version = [gem_dot_dash_split[-1]].concat(gem_dot_split[1..-2]).join('.')

      # Remove gem from geminabox - gem yank my-awesome-gem -v 1.0 --host HOST
      command = "gem yank #{gem_name} -v #{gem_version} --host #{GEMINABOX_URL}"
      Logger.info "Removing gem: #{command}"
      return run_command(command)
    end

    private

    def self.run_command(command)
      status = 0
      output = false
      thread = Thread.new do
        output, status = Open3.capture2e(command)
      end
      thread.join
      if status.success?
        return output
      else
        raise output
      end
    end
  end
end
