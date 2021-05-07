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

require 'cosmos/microservices/microservice'
require 'cosmos/models/activity_model'
require 'cosmos/models/notification_model'
require 'cosmos/models/timeline_model'
require 'cosmos/topics/timeline_topic'

require 'cosmos/script'


module Cosmos

  class TimelineWorker
    # The Timeline worker is a very simple thread pool worker. Once
    # the timeline manager has pushed a job to the schedule one of
    # these workers will run the CMD (command) or SCRIPT (script)
    # or anything that could be expanded in the future.

    def initialize(name:, scope:, queue:)
      @name = name
      @scope = scope
      @queue = queue
    end

    def run
      Logger.info "timeline thread running"
      while true
        activity = @queue.pop
        break if activity.nil?
        run_activity(activity)
      end
      Logger.info "timeine worker exiting"
    end

    def run_activity(activity)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      case activity.kind.upcase
        when 'CMD'
          run_cmd(activity)
        when 'SCRIPT'
          run_script(activity)
        when 'EXPIRE'
          clear_expired(activity)
        else
          Logger.error "Unknown kind passed to microservice #{@name}: #{activity.as_json.to_s}"
      end
      diff = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start # seconds as a float
      current_score = DateTime.now.strftime("%s").to_i
      Logger.info "#{@name} active_score: #{activity.score}, current_score: #{current_score}"
      Logger.info "#{@name} -> diff: #{diff}, duration: #{activity.duration}"
    end

    def run_cmd(activity)
      Logger.info "#{@name} run_cmd > #{activity.as_json.to_s}"
      begin
        resp = cmd_no_hazardous_check(activity.data["cmd"], scope: @scope)
        activity.commit(status: "complete", fulfillment: true)
      rescue StandardError => e
        activity.commit(status: "failed", message: e.message)
        Logger.error "#{@name} run_cmd failed > #{activity.as_json.to_s}, #{e.message}"
      end
    end

    def run_script(activity)
      Logger.info "#{@name} run_script > #{activity.as_json.to_s}"
      begin
        path = "/scripts/#{activity.data["script"]}/run"
        request = Net::HTTP::Post.new(path, "Content-Type" => "application/json")
        request.body = {"scope"=>@scope}.to_json
        response = Net::HTTP.new("cosmos-script-runner-api", 2902).request(request)
        activity.commit(status: "complete", message: "#{response.code}, #{response.body}", fulfillment: true)
      rescue StandardError => e
        activity.commit(status: "failed", message: e.message)
        Logger.error "#{@name} run_script failed > #{activity.as_json.to_s}, #{e.message}"
      end
    end

    def clear_expired(activity)
      Logger.info "#{@name} clear_expired > #{activity.as_json.to_s}"
      begin
        min = DateTime.parse(activity.start_time).strftime("%s").to_i
        max = DateTime.parse(activity.end_time).strftime("%s").to_i
        ret = TimelineModel.range_destroy(name: @name, scope: @scope, min: min, max: max)
      rescue StandardError => e
        Logger.error "#{@name} clear_expired failed > #{activity.as_json.to_s} #{e.message}"
      end
    end

  end

  class Schedule
    # Shared between the monitor thread and the manager thread to
    # share the planned activities. This should remaine a thread
    # safe implamentation.

    def initialize(name)
      @name = name
      @mutex = Mutex.new
      @activities = Array.new
    end

    def get_activities
      @mutex.synchronize do
        return @activities.dup
      end
    end

    def update(input_activities)
      @mutex.synchronize do
        @activities.clear
        input_activities.each do |activity|
          @activities << activity
        end
      end
    end

  end

  class TimelineManager
    # The timeline manager starts a thread pool and looks at the
    # schedule and if an "activity" should be run. TimelineManager
    # adds the "activity" to the thread pool and the thread will
    # execute the "activity".

    def initialize(name, schedule)
      split_name = name.split("__")
      @scope = split_name[0]
      @timeline_name = split_name[2]
      @schedule = schedule
      @worker_count = 3
      @queue = Queue.new
      @thread_pool = generate_thread_pool(@queue)
      @cancel_thread = false
      @count = 1.0
      @expire = 3000.0
    end

    def generate_thread_pool(queue)
      thread_pool = Array.new
      @worker_count.times {
        worker = TimelineWorker.new(name: @timeline_name, scope: @scope, queue: queue)
        thread_pool << Thread.new { worker.run }
      }
      return thread_pool
    end

    def run
      Logger.info "#{@timeline_name} timeine manager running"
      while true
        Logger.debug "#{@timeline_name} manager checking schedule for updates"
        score = DateTime.now.strftime("%s").to_i
        @schedule.get_activities().each do |activity|
          score_difference = activity.score - score
          Logger.debug "#{@timeline_name} #{@scope} current score: #{score}, vs #{activity.score}, #{score_difference}"
          if score_difference.zero?
            activity.add_event("queued")
            @queue << activity
          end
        end
        if @count >= @expire
          request_update(score: score)
          add_expire_activity()
        end
        break if @cancel_thread
        sleep(1)
        break if @cancel_thread
        @count += 1.0
      end
    end

    # Add task to remove events older than 7 time
    def add_expire_activity
      now = DateTime.now.new_offset(0)
      activity = ActivityModel.new(
        name: @name,
        scope: @scope,
        start_time: (now - (7.0 + (@expire + 100.0 / 86400.0))).to_s,
        end_time: (now - 7.0).to_s,
        kind: "EXPIRE",
        data: {})
      @queue << activity
    end

    # This can feedback to ensure the schedule will not run out so this should fire once an
    # hour to make sure the TimelineMicroservice will collect the next hour and update the
    # schedule.
    def request_update(score:)
      notification = {
        "data" => {"score" => score},
        "kind" => "status",
        "type" => "timeline",
        "timeline"=> @timeline_name}
      begin
        TimelineTopic.write_activity(notification, scope: @scope)
        @count = 1.0
      rescue StandardError
        Logger.error "#{@timeline_name} manager failed to request update"
      end
    end

    def shutdown
      @cancel_thread = true
      @worker_count.times {
        @queue << nil
      }
    end

  end

  class TimelineMicroservice < Microservice
    # The timeline microservice starts a manager then gets the activities
    # from the sorted set in redis and updates the schedule for the
    # manager. Timeline will then wait for an update on the timeline
    # stream this will trigger an update again to the schedule.

    TIMELINE_METRIC_NAME = "timeline_activities_duration_seconds"

    def initialize(name)
      super(name)
      split_name = name.split("__")
      @timeline_name = split_name[2]
      @schedule = Schedule.new(@timeline_name)
      @manager = TimelineManager.new(name, @schedule)
      @manager_thread = nil
    end

    def run
      Logger.info "#{@timeline_name} #{@scope} timeine running"
      @worker_thread = Thread.new { @manager.run }
      while true
        score = DateTime.now.strftime("%s").to_i
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        current_activities = ActivityModel.activities(name: @timeline_name, scope: @scope)
        diff = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start # seconds as a float
        metric_labels = { "timeline" => @timeline_name }
        @metric.add_sample(name: TIMELINE_METRIC_NAME, value: diff, labels: metric_labels)
        @schedule.update(current_activities)
        break if @cancel_thread
        block_for_updates()
        break if @cancel_thread
      end
    end

    def block_for_updates
      read_topic = false
      while read_topic == false
        begin
          TimelineTopic.read_topics(@topics) do |topic, msg_id, msg_hash, redis|
            message = JSON.parse(msg_hash["json_data"])
            if message["timeline"] == @timeline_name
              read_topic = true
            end
          end
        rescue Exception => err
          Logger.error "#{@timeline_name} failed to read topics #{@topics} from #{@interface.name}\n#{err.formatted}"
        end
      end
    end

    def shutdown
      @manager.shutdown
      super
    end

  end

end

Cosmos::TimelineMicroservice.run if __FILE__ == $0
