# Script Runner test script
cmd("<%= target_name %> EXAMPLE")
wait_check("<%= target_name %> STATUS BOOL == 'FALSE'", 5)
