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

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved

require 'tempfile'
require 'openc3/utilities/s3'
require 'openc3/script/suite'
require 'openc3/script/suite_runner'
require 'openc3/tools/test_runner/test'

OpenC3.require_file 'openc3/utilities/store'

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
    rescue Aws::S3::Errors::NoSuchKey
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
    OpenC3::Store.hset("#{scope}__script-locks", name, user)
  end

  def self.unlock(scope, name)
    name = name.split('*')[0] # Split '*' that indicates modified
    OpenC3::Store.hdel("#{scope}__script-locks", name)
  end

  def self.locked?(scope, name)
    name = name.split('*')[0] # Split '*' that indicates modified
    locked_by = OpenC3::Store.hget("#{scope}__script-locks", name)
    locked_by ||= false
    locked_by
  end

  def self.get_breakpoints(scope, name)
    breakpoints = OpenC3::Store.hget("#{scope}__script-breakpoints", name.split('*')[0]) # Split '*' that indicates modified
    return JSON.parse(breakpoints, :allow_nan => true, :create_additions => true) if breakpoints
    []
  end

  def self.process_suite(name, contents, new_process: true, scope:)
    start = Time.now
    temp = Tempfile.new(%w[suite .rb])

    # Remove any carriage returns which ruby doesn't like
    temp.write(contents.gsub(/\r/, ' '))
    temp.close

    # We open a new ruby process so as to not pollute the API with require
    results = nil
    success = true
    if new_process
      runner_path = File.join(RAILS_ROOT, 'scripts', 'run_suite_analysis.rb')
      process = ChildProcess.build('ruby', runner_path.to_s, scope, temp.path)
      process.cwd = File.join(RAILS_ROOT, 'scripts')

      # Set proper secrets for running script
      process.environment['SECRET_KEY_BASE'] = nil
      process.environment['OPENC3_REDIS_USERNAME'] = ENV['OPENC3_SR_REDIS_USERNAME']
      process.environment['OPENC3_REDIS_PASSWORD'] = ENV['OPENC3_SR_REDIS_PASSWORD']
      process.environment['OPENC3_MINIO_USERNAME'] = ENV['OPENC3_SR_MINIO_USERNAME']
      process.environment['OPENC3_MINIO_PASSWORD'] = ENV['OPENC3_SR_MINIO_PASSWORD']
      process.environment['OPENC3_SR_REDIS_USERNAME'] = nil
      process.environment['OPENC3_SR_REDIS_PASSWORD'] = nil
      process.environment['OPENC3_SR_MINIO_USERNAME'] = nil
      process.environment['OPENC3_SR_MINIO_PASSWORD'] = nil
      process.environment['OPENC3_API_USER'] = ENV['OPENC3_API_USER']
      process.environment['OPENC3_API_PASSWORD'] = ENV['OPENC3_API_PASSWORD'] || ENV['OPENC3_SERVICE_PASSWORD']
      process.environment['OPENC3_API_CLIENT'] = ENV['OPENC3_API_CLIENT']
      process.environment['OPENC3_API_SECRET'] = ENV['OPENC3_API_SECRET']
      process.environment['GEM_HOME'] = ENV['GEM_HOME']

      # Spawned process should not be controlled by same Bundler constraints as spawning process
      ENV.each do |key, value|
        if key =~ /^BUNDLE/
          process.environment[key] = nil
        end
      end
      process.environment['RUBYOPT'] = nil # Removes loading bundler setup
      stdout = Tempfile.new("child-stdout")
      stdout.sync = true
      stderr = Tempfile.new("child-stderr")
      stderr.sync = true
      process.io.stdout = stdout
      process.io.stderr = stderr
      process.start
      process.wait
      stdout.rewind
      stdout_results = stdout.read
      stdout.close
      stdout.unlink
      stderr.rewind
      stderr_results = stderr.read
      stderr.close
      stderr.unlink
      success = process.exit_code == 0
    else
      require temp.path
      stdout_results = OpenC3::SuiteRunner.build_suites.as_json(:allow_nan => true).to_json(:allow_nan => true)
    end
    temp.delete
    puts "Processed #{name} in #{Time.now - start} seconds"
    # Make sure we're getting the last line which should be the suite
    puts "Stdout Results:#{stdout_results}:"
    puts "Stderr Results:#{stderr_results}:"
    stdout_results = stdout_results.split("\n")[-1] if stdout_results
    return stdout_results, stderr_results, success
  end

  def self.create(scope, name, text = nil, breakpoints = nil)
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
    OpenC3::Store.hset("#{scope}__script-breakpoints", name, breakpoints.as_json(:allow_nan => true).to_json(:allow_nan => true)) if breakpoints
    true
  end

  def self.destroy(scope, name)
    rubys3_client = Aws::S3::Client.new

    # Only delete file from the modified target directory
    rubys3_client.delete_object(
      key: "#{scope}/targets_modified/#{name}",
      bucket: DEFAULT_BUCKET_NAME,
    )
    OpenC3::Store.hdel("#{scope}__script-breakpoints", name)
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

  def self.instrumented(filename, text)
    {
      'title' => 'Instrumented Script',
      'description' =>
        RunningScript.instrument_script(
          text,
          filename,
          true,
        ).split("\n").as_json(:allow_nan => true).to_json(:allow_nan => true),
    }
  end

  def self.syntax(text)
    check_process = IO.popen('ruby -c -rubygems 2>&1', 'r+')
    check_process.write("require 'openc3'; require 'openc3/script'; " + text)
    check_process.close_write
    results = check_process.readlines
    check_process.close
    if results
      if results.any?(/Syntax OK/)
        return(
          {
            'title' => 'Syntax Check Successful',
            'description' => results.as_json(:allow_nan => true).to_json(:allow_nan => true),
          }
        )
      else
        # Results is an array of strings like this: ":2: syntax error ..."
        # Normally the procedure comes before the first colon but since we
        # are writing to the process this is blank so we throw it away
        results.map! { |result| result.split(':')[1..-1].join(':') }
        return(
          { 'title' => 'Syntax Check Failed', 'description' => results.as_json(:allow_nan => true).to_json(:allow_nan => true) }
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
