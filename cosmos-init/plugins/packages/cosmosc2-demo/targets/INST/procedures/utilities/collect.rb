load_utility '<%= target_name %>/procedures/utilities/clear.rb'

def collect(type, duration, call_clear = false)
  # Get the current collects telemetry point
  collects = tlm('<%= target_name %> HEALTH_STATUS COLLECTS')

  # Command the collect
  cmd("<%= target_name %> COLLECT with TYPE #{type}, DURATION #{duration}")

  # Wait for telemetry to update
  wait_check("<%= target_name %> HEALTH_STATUS COLLECTS == #{collects + 1}", 10)

  clear() if call_clear
end
