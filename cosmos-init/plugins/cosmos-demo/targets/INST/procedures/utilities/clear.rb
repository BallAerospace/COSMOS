def clear
  # Command the collect
  cmd("<%= target_name %> CLEAR")

  # Wait for telemetry to update
  wait_check("<%= target_name %> HEALTH_STATUS COLLECTS == 0", 10)
end
