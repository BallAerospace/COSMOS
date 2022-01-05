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

require 'tempfile'
require 'cosmos/script/suite'
require 'cosmos/script/suite_runner'
require 'cosmos/tools/test_runner/test'
require 'cosmos/utilities/s3'

Cosmos.require_file 'cosmos/utilities/store'

class Script
  DEFAULT_BUCKET_NAME = 'config'

  def self.all(scope)
    rubys3_client = Aws::S3::Client.new
    resp = rubys3_client.list_objects_v2(bucket: DEFAULT_BUCKET_NAME)
    result = []
    modified = []
    contents = resp.to_h[:contents]
    if contents
      contents.each do |object|
        next unless object[:key].include?("#{scope}/targets")

        if object[:key].include?('procedures') || object[:key].include?('lib')
          if object[:key].include?("#{scope}/targets_modified")
            modified << object[:key].split('/')[2..-1].join('/')
            next
          end
          result << object[:key].split('/')[2..-1].join('/')
        end
      end
    end

    # Determine if there are any modified files and mark them with '*'
    result.map! do |file|
      if modified.include?(file)
        modified.delete(file)
        "#{file}*"
      else
        file
      end
    end

    # Concat any remaining modified files (new files not in original target)
    result.concat(modified)
    result.sort
  end

  def self.body(scope, name)
    name = name.split('*')[0] # Split '*' that indicates modified
    rubys3_client = Aws::S3::Client.new
    begin
      # First try opening a potentially modified version by looking for the modified target
      resp =
        rubys3_client.get_object(
          bucket: DEFAULT_BUCKET_NAME,
          key: "#{scope}/targets_modified/#{name}",
        )
    rescue StandardError
      # Now try the original
      resp =
        rubys3_client.get_object(
          bucket: DEFAULT_BUCKET_NAME,
          key: "#{scope}/targets/#{name}",
        )
    end
    resp.body.read
  end

  def self.lock(scope, name, user)
    name = name.split('*')[0] # Split '*' that indicates modified
    Cosmos::Store.hset("#{scope}__script-locks", name, user)
  end

  def self.unlock(scope, name)
    name = name.split('*')[0] # Split '*' that indicates modified
    Cosmos::Store.hdel("#{scope}__script-locks", name)
  end

  def self.locked?(scope, name)
    name = name.split('*')[0] # Split '*' that indicates modified
    locked_by = Cosmos::Store.hget("#{scope}__script-locks", name)
    locked_by ||= false
    locked_by
  end

  def self.process_suite(name, contents, new_process: true)
    start = Time.now
    temp = Tempfile.new(%w[suite .rb])

    # Remove any carriage returns which ruby doesn't like
    temp.write(contents.gsub(/\r/, ' '))
    temp.close

    # We open a new ruby process so as to not pollute the API with require
    results = nil
    success = true
    if new_process
      check_process = IO.popen('ruby 2>&1', 'r+')
      check_process.write(
        "require 'json'; require 'cosmos/script/suite_runner'; require '#{temp.path}'; puts Cosmos::SuiteRunner.build_suites.to_json",
      )
      check_process.close_write
      results = check_process.readlines
      check_process.close

      # Once close is called Ruby sets the $? variable which is a Process::Status instance
      # See https://www.rubydoc.info/stdlib/core/IO.popen & https://www.rubydoc.info/stdlib/core/Process/Status
      success = $?.success?
    else
      require temp.path
      Cosmos::SuiteRunner.build_suites
    end
    temp.delete
    puts "Processed #{name} in #{Time.now - start} seconds"
    puts "Results: #{results}"
    return results, success
  end

  def self.create(scope, name, text = nil)
    return false unless text

    rubys3_client = Aws::S3::Client.new
    rubys3_client.put_object(
      # Use targets_modified to save modifications
      # This keeps the original target clean (read-only)
      key: "#{scope}/targets_modified/#{name}",
      body: text,
      bucket: DEFAULT_BUCKET_NAME,
      content_type: 'text/plain',
    )
    true
  end

  def self.destroy(scope, name)
    rubys3_client = Aws::S3::Client.new

    # Only delete file from the modified target directory
    rubys3_client.delete_object(
      key: "#{scope}/targets_modified/#{name}",
      bucket: DEFAULT_BUCKET_NAME,
    )
    true
  end

  def self.run(
    scope,
    name,
    suite_runner = nil,
    disconnect = false,
    environment = nil
  )
    RunningScript.spawn(scope, name, suite_runner, disconnect, environment)
  end

  def self.instrumented(text)
    {
      'title' => 'Instrumented Script',
      'description' =>
        RunningScript.instrument_script(
          text,
          File.build_timestamped_filename,
          true,
        ).split("\n").to_json,
    }
  end

  def self.syntax(text)
    check_process = IO.popen('ruby -c -rubygems 2>&1', 'r+')
    check_process.write("require 'cosmos'; require 'cosmos/script'; " + text)
    check_process.close_write
    results = check_process.readlines
    check_process.close
    if results
      if results.any?(/Syntax OK/)
        return(
          {
            'title' => 'Syntax Check Successful',
            'description' => results.to_json,
          }
        )
      else
        # Results is an array of strings like this: ":2: syntax error ..."
        # Normally the procedure comes before the first colon but since we
        # are writing to the process this is blank so we throw it away
        results.map! { |result| result.split(':')[1..-1].join(':') }
        return(
          { 'title' => 'Syntax Check Failed', 'description' => results.to_json }
        )
      end
    else
      return(
        {
          'title' => 'Syntax Check Exception',
          'description' => 'Ruby syntax check unexpectedly returned nil',
        }
      )
    end
  end
end
