def my_method
  while 1
    sleep 1
    puts 1
  end
end
my_method()
status_bar("Status bar message")
wait 3

cmd("WHAT CMD")
cmd("COSMOS STARTCMDLOG with X")
cmd("COSMOS STARTCMDLOG with SOMETHING BIG")
tlm("THIS WILL FAIL")
tlm("COSMOS LIMITS_CHANGE ITEM CHECK")
set_tlm("THIS WILL FAIL = 5")

if true do puts "HI"
