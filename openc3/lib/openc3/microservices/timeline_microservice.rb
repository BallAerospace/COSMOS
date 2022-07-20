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

require 'openc3/utilities/authentication'
require 'openc3/microservices/microservice'
require 'openc3/models/activity_model'
require 'openc3/models/notification_model'
require 'openc3/models/timeline_model'
require 'openc3/topics/timeline_topic'

require 'openc3/script'

module OpenC3
  # The Timeline worker is a very simple thread pool worker. Once
  # the timeline manager has pushed a job to the schedule one of
  # these workers will run the CMD (command) or SCRIPT (script)
  # or anything that could be expanded in the future.
  class TimelineWorker
    def initialize(name:, scope:, queue:)
      @timeline_name = name
      @scope = scope
      @queue = queue
      @authentication = generate_auth()
    end

    # generate the auth object
    def generate_auth
      if ENV['OPENC3_API_USER'].nil? || ENV['OPENC3_API_CLIENT'].nil?
        return OpenC3Authentication.new()
      else
        return OpenC3KeycloakAuthentication.new(ENV['OPENC3_KEYCLOAK_URL'])
      end
    end

    def run
      Logger.info "#{@timeline_name} timeline worker running"
      loop do
        activity = @queue.pop
        break if activity.nil?

        run_activity(activity)
      end
      Logger.info "#{@timeline_name} timeine worker exiting"
    end

    def run_activity(activity)
      case activity.kind.upcase
      when 'COMMAND'
        run_command(activity)
      when 'SCRIPT'
        run_script(activity)
      when 'EXPIRE'
        clear_expired(activity)
      else
        Logger.error "Unknown kind passed to microservice #{@timeline_name}: #{activity.as_json(:allow_nan => true)}"
      end
    end

    def run_command(activity)
      Logger.info "#{@timeline_name} run_command > #{activity.as_json(:allow_nan => true)}"
      begin
        cmd_no_hazardous_check(activity.data['command'], scope: @scope)
        activity.commit(status: 'completed', fulfillment: true)
      rescue StandardError => e
        activity.commit(status: 'failed', message: e.message)
        Logger.error "#{@timeline_name} run_cmd failed > #{activity.as_json(:allow_nan => true)}, #{e.message}"
      end
    end

    def run_script(activity)
      Logger.info "#{@timeline_name} run_script > #{activity.as_json(:allow_nan => true)}"
      begin
        request = Net::HTTP::Post.new(
          "/script-api/scripts/#{activity.data['script']}/run?scope=#{@scope}",
          'Content-Type' => 'application/json',
          'Authorization' => @authentication.token()
        )
        request.body = JSON.generate({
          'scope' => @scope,
          'environment' => activity.data['environment'],
          'timeline' => @timeline_name,
          'id' => activity.start
        })
        hostname = ENV['OPENC3_SCRIPT_HOSTNAME'] || 'openc3-script-runner-api'
        response = Net::HTTP.new(hostname, 2902).request(request)
        raise "failed to call #{hostname}, for script: #{activity.data['script']}, response code: #{response.code}" if response.code != '200'

        activity.commit(status: 'completed', message: "#{activity.data['script']} => #{response.body}", fulfillment: true)
      rescue StandardError => e
        activity.commit(status: 'failed', message: e.message)
        Logger.error "#{@timeline_name} run_script failed > #{activity.as_json(:allow_nan => true).to_s}, #{e.message}"
      end
    end

    def clear_expired(activity)
      begin
        ActivityModel.range_destroy(name: @timeline_name, scope: @scope, min: activity.start, max: activity.stop)
        activity.add_event(status: 'completed')
      rescue StandardError => e
        Logger.error "#{@timeline_name} clear_expired failed > #{activity.as_json(:allow_nan => true)} #{e.message}"
      end
    end
  end

  # Shared between the monitor thread and the manager thread to
  # share the planned activities. This should remain a thread
  # safe implamentation.
  class Schedule
    def initialize(name)
      @name = name
      @activities_mutex = Mutex.new
      @activities = []
      @size = 20
      @queue = Array.new(@size)
      @index = 0
    end

    def not_queued?(start)
      return false if @queue.index(start)

      @queue[@index] = start
      @index = @index + 1 >= @size ? 0 : @index + 1
      return true
    end

    def activities
      @activities_mutex.synchronize do
        return @activities.dup
      end
    end

    def update(input_activities)
      @activities_mutex.synchronize do
        @activities = input_activities.dup
      end
    end

    def add_activity(input_activity)
      @activities_mutex.synchronize do
        if @activities.find { |x| x.start == input_activity.start }.nil?
          @activities << input_activity
        end
      end
    end

    def remove_activity(input_activity)
      @activities_mutex.synchronize do
        @activities.delete_if { |h| h.start == input_activity.start }
      end
    end
  end

  # The timeline manager starts a thread pool and looks at the
  # schedule and if an "activity" should be run. TimelineManager
  # adds the "activity" to the thread pool and the thread will
  # execute the "activity".
  class TimelineManager
    def initialize(name:, scope:, schedule:)
      @timeline_name = name
      @scope = scope
      @schedule = schedule
      @worker_count = 3
      @queue = Queue.new
      @thread_pool = generate_thread_pool()
      @cancel_thread = false
      @expire = 0
    end

    def generate_thread_pool
      thread_pool = []
      @worker_count.times {
        worker = TimelineWorker.new(name: @timeline_name, scope: @scope, queue: @queue)
        thread_pool << Thread.new { worker.run }
      }
      return thread_pool
    end

    def run
      Logger.info "#{@timeline_name} timeline manager running"
      loop do
        start = Time.now.to_i
        @schedule.activities.each do |activity|
          start_difference = activity.start - start
          if start_difference <= 0 && @schedule.not_queued?(activity.start)
            Logger.debug "#{@timeline_name} #{@scope} current start: #{start}, vs #{activity.start}, #{start_difference}"
            activity.add_event(status: 'queued')
            @queue << activity
          end
        end
        if start >= @expire
          add_expire_activity()
          request_update(start: start)
        end
        break if @cancel_thread

        sleep(1)
        break if @cancel_thread
      end
      Logger.info "#{@timeline_name} timeine manager exiting"
    end

    # Add task to remove events older than 7 time
    def add_expire_activity
      now = Time.now.to_i
      @expire = now + 3_000
      activity = ActivityModel.new(
        name: @timeline_name,
        scope: @scope,
        start: (now - 86_400 * 7),
        stop: (now - 82_800 * 7),
        kind: 'EXPIRE',
        data: {}
      )
      @queue << activity
      return activity
    end

    # This can feedback to ensure the schedule will not run out so this should fire once an
    # hour to make sure the TimelineMicroservice will collect the next hour and update the
    # schedule.
    def request_update(start:)
      notification = {
        'data' => JSON.generate({ 'time' => start }),
        'kind' => 'refresh',
        'type' => 'timeline',
        'timeline' => @timeline_name
      }
      begin
        TimelineTopic.write_activity(notification, scope: @scope)
      rescue StandardError
        Logger.error "#{@name} manager failed to request update"
      end
    end

    def shutdown
      @cancel_thread = true
      @worker_count.times {
        @queue << nil
      }
    end
  end

  # The timeline microservice starts a manager then gets the activities
  # from the sorted set in redis and updates the schedule for the
  # manager. Timeline will then wait for an update on the timeline
  # stream this will trigger an update again to the schedule.
  class TimelineMicroservice < Microservice
    TIMELINE_METRIC_NAME = 'timeline_activities_duration_seconds'.freeze

    def initialize(name)
      super(name)
      @timeline_name = name.split('__')[2]
      @schedule = Schedule.new(@timeline_name)
      @manager = TimelineManager.new(name: @timeline_name, scope: scope, schedule: @schedule)
      @manager_thread = nil
      @read_topic = true
    end

    def run
      Logger.info "#{@name} timeine running"
      @manager_thread = Thread.new { @manager.run }
      loop do
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        current_activities = ActivityModel.activities(name: @timeline_name, scope: @scope)
        @schedule.update(current_activities)
        diff = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start # seconds as a float
        metric_labels = { 'timeline' => @timeline_name, 'thread' => 'microservice' }
        @metric.add_sample(name: TIMELINE_METRIC_NAME, value: diff, labels: metric_labels)
        break if @cancel_thread

        block_for_updates()
        break if @cancel_thread
      end
      Logger.info "#{@name} timeine exitting"
    end

    def topic_lookup_functions
      {
        'timeline' => {
          'created' => :timeline_nop,
          'refresh' => :schedule_refresh,
          'updated' => :timeline_nop,
          'deleted' => :timeline_nop
        },
        'activity' => {
          'event' => :timeline_nop,
          'created' => :create_activity_from_event,
          'updated' => :schedule_refresh,
          'deleted' => :remove_activity_from_event
        }
      }
    end

    def block_for_updates
      @read_topic = true
      while @read_topic
        begin
          TimelineTopic.read_topics(@topics) do |_topic, _msg_id, msg_hash, _redis|
            if msg_hash['timeline'] == @timeline_name
              data = JSON.parse(msg_hash['data'], :allow_nan => true, :create_additions => true)
              public_send(topic_lookup_functions[msg_hash['type']][msg_hash['kind']], data)
            end
          end
        rescue StandardError => e
          Logger.error "#{@timeline_name} failed to read topics #{@topics}\n#{e.formatted}"
        end
      end
    end

    def timeline_nop(data)
      Logger.debug "#{@name} timeline web socket event: #{data}"
    end

    def schedule_refresh(data)
      Logger.debug "#{@name} timeline web socket schedule refresh: #{data}"
      @read_topic = false
    end

    # Add the activity to the schedule. We don't need to hold the job in memory
    # if it is longer than an hour away. A refresh task will update that.
    def create_activity_from_event(data)
      diff = data['start'] - Time.now.to_i
      return unless (2..3600).include? diff

      activity = ActivityModel.from_json(data, name: @timeline_name, scope: @scope)
      @schedule.add_activity(activity)
    end

    # Remove the activity from the schedule. We don't need to remove the activity
    # if it is longer than an hour away. It will be removed from the data.
    def remove_activity_from_event(data)
      diff = data['start'] - Time.now.to_i
      return unless (2..3600).include? diff

      activity = ActivityModel.from_json(data, name: @timeline_name, scope: @scope)
      @schedule.remove_activity(activity)
    end

    def shutdown
      @read_topic = false
      @manager.shutdown
      super
    end
  end
end

OpenC3::TimelineMicroservice.run if __FILE__ == $0
