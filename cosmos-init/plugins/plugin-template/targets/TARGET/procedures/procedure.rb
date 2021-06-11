# Script Runner test script
cmd("<%= target_name %> COMMAND")
wait_check("<%= target_name %> STATUS BOOL == 'FALSE'", 5)
