load_utility 'clear_util.rb'

def collect (type, duration, call_clear = false)
  # Get the current collects telemetry point
  collects = tlm('INST HEALTH_STATUS COLLECTS')

  #Command the collect
  cmd("INST COLLECT with TYPE #{type}, DURATION #{duration}")

  #Wait for telemetry to update
  wait_check("INST HEALTH_STATUS COLLECTS == #{collects + 1}", 10)

  clear_collects() if call_clear
end
