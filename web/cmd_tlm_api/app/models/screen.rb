# encoding: ascii-8bit

# Copyright 2020 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'aws-sdk-s3'

Aws.config.update(
  endpoint: 'http://localhost:9000',
  access_key_id: 'minioadmin',
  secret_access_key: 'minioadmin',
  force_path_style: true,
  region: 'us-east-1'
)

class Screen
  DEFAULT_BUCKET_NAME = 'targets'

  def self.all(target)
    rubys3_client = Aws::S3::Client.new
    resp = rubys3_client.list_objects_v2(bucket: DEFAULT_BUCKET_NAME)
    result = []
    contents = resp.to_h[:contents]
    if contents
      contents.each do |object|
        next unless object[:key].include?("#{target}/screens/")
        filename = object[:key].split('/')[-1]
        next unless filename.include?(".txt")
        next if filename[0] == '_' # underscore filenames are partials
        result << File.basename(filename, ".txt").upcase
      end
    end
    result.sort
  end

  def self.find(target, screen)
    rubys3_client = Aws::S3::Client.new
    resp = rubys3_client.get_object(bucket: DEFAULT_BUCKET_NAME, key: "#{target}/screens/#{screen}.txt")
    @target_name = target
    ERB.new(resp.body.read).result(binding)
  end

  # Called by the ERB template to render a partial
  def self.render(template_name, options = {})
    raise Error.new(self, "Partial name '#{template_name}' must begin with an underscore.") if File.basename(template_name)[0] != '_'
    b = binding
    if options[:locals]
      options[:locals].each {|key, value| b.local_variable_set(key, value) }
    end
    rubys3_client = Aws::S3::Client.new
    resp = rubys3_client.get_object(bucket: DEFAULT_BUCKET_NAME, key: "#{@target_name}/screens/#{template_name}")
    ERB.new(resp.body.read).result(b)
  end
end
