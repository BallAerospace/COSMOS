# Specify the title and message
file = open_file_dialog("Open a single file", "Choose something interesting")
puts file # Ruby File object
puts file.read
file.delete

files = open_files_dialog("Open multiple files") # message is optional
puts files # Array of File objects (even if you select only one)
files.each do |file|
  puts file
  puts file.read
  file.delete
end
