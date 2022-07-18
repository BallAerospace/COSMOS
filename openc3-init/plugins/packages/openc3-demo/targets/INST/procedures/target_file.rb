put_target_file("INST/test.txt", "this is a string test")
file = get_target_file("INST/test.txt")
puts file.read
file.delete
delete_target_file("INST/test.txt")

save_file = Tempfile.new('test')
save_file.write("this is a Io test")
save_file.rewind
put_target_file("INST/test.txt", save_file)
save_file.delete
file = get_target_file("INST/test.txt")
puts file.read
file.delete
delete_target_file("INST/test.txt")

put_target_file("INST/test.bin", "\x00\x01\x02\x03\xFF\xEE\xDD\xCC")
file = get_target_file("INST/test.bin")
puts file.read.formatted
file.delete
delete_target_file("INST/test.bin")
