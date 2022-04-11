put_target_file("INST/test.txt", "this is a test")
file = get_target_file("INST/test.txt")
puts file.read
puts file.read.formatted
delete_target_file("INST/test.txt")

put_target_file("INST/test.bin", "\x00\x01\x02\x03\xFF\xEE\xDD\xCC")
file = get_target_file("INST/test.bin", binary: true)
puts file.read.formatted
delete_target_file("INST/test.bin")
