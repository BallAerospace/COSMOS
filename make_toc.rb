MAX_OFFSET = 1

file_list = [
'_docs/scripting.md',
'_docs/system.md',
'_docs/cmdtlm.md',
'_docs/interfaces.md',
'_docs/tools.md',
'_docs/screens.md',
'_docs/requirements.md',
]

file_list.each do |filename|
  puts "Creating TOC for #{filename}"
  file_data = File.read(filename)

  page_toc = "### Table of Contents\n\n"
  in_code_block = false
  first = true
  offset = 1
  file_data.each_line do |line|
    if line =~ /^\s*```.*```/
      # Inline code block - skip
    elsif line =~ /% highlight/
      in_code_block = true
    elsif line =~ /% endhighlight/
      in_code_block = false
    elsif line =~ /^\s*```/
      in_code_block = !in_code_block
    elsif line =~ /^\s*(#+) (.*)/ and !in_code_block
      if first
        offset = $1.length
      end
      current_offset = $1.length - offset
      current_offset = 0 if current_offset < 0
      current_offset = MAX_OFFSET if current_offset > MAX_OFFSET
      page_toc << "<br/>\n" if current_offset == 0 and !first
      first = false
      if current_offset == 0
        page_toc << "<span>[#{$2}](##{$2.downcase.strip.gsub(" ", "-").gsub("_", "")})</span><br/>\n"
      else
        page_toc << "#{("&nbsp;" * (current_offset * 4))} [#{$2}](##{$2.downcase.strip.gsub(" ", "-").gsub("_", "")})<br/>\n"
      end
    end
  end

  # Create _toc.md for this file
  File.open("_includes/" + File.basename(filename)[0..-4] + "_toc.md", "w") do |file|
    file.write(page_toc)
  end
end
