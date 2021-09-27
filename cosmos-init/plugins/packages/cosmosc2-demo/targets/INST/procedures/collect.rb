load_utility '<%= target_name %>/procedures/utilities/collect.rb'
load_utility '<%= target_name %>/procedures/utilities/clear.rb'

number = ask("Enter a number.")
raise "Bad return" unless number.is_a? Numeric
number = ask_string("Enter a number.")
raise "Bad return" unless number.is_a? String

result = message_box("Click something.", "CHOICE1", "CHOICE2")
raise "Bad return" unless result == 'CHOICE1' or result == 'CHOICE2'

prompt("Press Ok to start NORMAL Collect")
collect('NORMAL', 1)
prompt("Press Ok to start SPECIAL Collect")
collect('SPECIAL', 2, true)
clear()

wait_check("<%= target_name %> HEALTH_STATUS COLLECTS == 0", 10)
