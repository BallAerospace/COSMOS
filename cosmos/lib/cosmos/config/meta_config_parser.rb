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

require 'erb'
require 'psych'
require 'tempfile'

class Array
  def to_meta_config_yaml(indentation = 0)
    Psych.dump(self).split("\n")[1..-1].join("\n#{' ' * indentation}")
  end
end

class Hash
  def to_meta_config_yaml(indentation = 0)
    Psych.dump(self).split("\n")[1..-1].join("\n#{' ' * indentation}")
  end
end

module Cosmos
  # Reads YAML formatted files describing a configuration file
  class MetaConfigParser
    @basedir = ''
    def self.load(filename)
      data = nil
      if File.exist?(filename)
        path = filename
        @basedir = File.dirname(filename)
      else
        path = File.join(@basedir, filename)
      end
      tf = Tempfile.new("temp.yaml")
      output = ERB.new(File.read(path)).result(binding)
      tf.write(output)
      tf.close
      begin
        data = Psych.safe_load(File.read(tf.path), aliases: true)
      rescue => error
        error_file = "#{filename}.err"
        File.open(error_file, 'w') { |file| file.puts output }
        raise error.exception("#{error.message}\n\nParsed output written to #{File.expand_path(error_file)}\n")
      end
      tf.unlink
      data
    end

    def self.dump(object, filename)
      File.open(filename, 'w') do |file|
        file.write Psych.dump(object)
      end
    end
  end
end
