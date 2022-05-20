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

require 'cosmos/utilities/s3'

class Screen
  DEFAULT_BUCKET_NAME = 'config'

  def self.all(scope, target)
    rubys3_client = Aws::S3::Client.new
    resp = rubys3_client.list_objects_v2(bucket: DEFAULT_BUCKET_NAME)
    result = []
    modified = []
    contents = resp.to_h[:contents]
    if contents
      contents.each do |object|
        if object[:key].include?("#{scope}/targets_modified/#{target}/screens/")
          filename = object[:key].split('/')[-1]
          next unless filename.include?(".txt")
          next if filename[0] == '_' # underscore filenames are partials
          modified << File.basename(filename, ".txt").upcase
        end
        if object[:key].include?("#{scope}/targets/#{target}/screens/")
          filename = object[:key].split('/')[-1]
          next unless filename.include?(".txt")
          next if filename[0] == '_' # underscore filenames are partials
          result << File.basename(filename, ".txt").upcase
        end
      end
    end
    # Determine if there are any modified files and eliminate originals
    result.map! do |file|
      if modified.include?(file)
        modified.delete(file)
      else
        file
      end
    end
    # Concat any remaining modified files (new files not in original target)
    result.concat(modified)
    result.sort
  end

  def self.find(scope, target, screen)
    rubys3_client = Aws::S3::Client.new
    begin
      # First try opening a potentially modified version by looking for the modified target
      resp = rubys3_client.get_object(bucket: DEFAULT_BUCKET_NAME, key: "#{scope}/targets_modified/#{target}/screens/#{screen}.txt")
    rescue
      # Now try the original
      resp = rubys3_client.get_object(bucket: DEFAULT_BUCKET_NAME, key: "#{scope}/targets/#{target}/screens/#{screen}.txt")
    end
    @scope = scope
    @target = target
    return resp.body.read
    # # Remove all the commented out lines to prevent ERB from running
    # file.gsub!(/^\s*#.*\n/,'')
    # ERB.new(file, trim_mode: "-").result(binding)
  end

  # TODO: This should not be needed as screens should be fully rendered in S3
  # # Called by the ERB template to render a partial
  # def self.render(template_name, options = {})
  #   raise Error.new(self, "Partial name '#{template_name}' must begin with an underscore.") if File.basename(template_name)[0] != '_'
  #   b = binding
  #   if options[:locals]
  #     options[:locals].each {|key, value| b.local_variable_set(key, value) }
  #   end
  #   rubys3_client = Aws::S3::Client.new
  #   begin
  #     # First try opening a potentially modified version by looking for the modified target
  #     resp = rubys3_client.get_object(bucket: DEFAULT_BUCKET_NAME, key: "#{scope}/targets_modified/#{target}/screens/#{template_name}")
  #   rescue
  #     # Now try the original
  #     resp = rubys3_client.get_object(bucket: DEFAULT_BUCKET_NAME, key: "#{scope}/targets/#{target}/screens/#{template_name}")
  #   end
  #   ERB.new(resp.body.read, trim_mode: "-").result(b)
  # end

  def self.create(scope, target, screen, text = nil)
    return false unless text
    rubys3_client = Aws::S3::Client.new
    rubys3_client.put_object(
      # Use targets_modified to save modifications
      # This keeps the original target clean (read-only)
      key: "#{scope}/targets_modified/#{target}/screens/#{screen}.txt",
      body: text,
      bucket: DEFAULT_BUCKET_NAME,
      content_type: 'text/plain')
    true
  end
end
