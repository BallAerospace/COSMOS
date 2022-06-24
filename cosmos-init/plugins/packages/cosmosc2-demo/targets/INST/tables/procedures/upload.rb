# TBL_FILENAME is set to the name of the table file
puts "file:#{ENV['TBL_FILENAME']}"
# Open the file
file = get_target_file(ENV['TBL_FILENAME'])
buffer = file.read
# puts buffer.formatted
# Implement custom commanding logic to upload the table
# Note that buffer is a Ruby string of bytes
# You probably want to do something like:
# buf_size = 512 # Size of a buffer in the upload command
# i = 0
# while i < buffer.length
#   # Send a part of the buffer
#   # NOTE: triple dots means start index, up to but not including, end index
#   #   while double dots means start index, up to AND including, end index
#   cmd("TGT", "UPLOAD", "DATA" => buffer[i...(i + buf_size)])
#   i += buf_size
# end
file.delete
