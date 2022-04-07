write_target_file("INST/test.txt", "this is a test")
puts read_target_file("INST/test.txt")
puts read_target_file("INST/test.txt", 'rb').formatted
delete_target_file("INST/test.txt")

write_target_file("INST/test.bin", "\x00\x01\x02\x03\xFF\xEE\xDD\xCC", 'wb')
# puts read_target_file("INST/test.bin").formatted #=> Fails due to ArgumentError : invalid byte sequence in UTF-8
puts read_target_file("INST/test.bin", 'rb').formatted
delete_target_file("INST/test.bin")
