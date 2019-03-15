answer = combo_box("This is a plain combo box", 'one', 'two', 'three', informative: nil)
puts "answer:#{answer}"
answer = combo_box("This is a combo box with info", 'one', 'two', 'three', informative: 'This is informative')
puts "answer:#{answer}"
answer = combo_box("This is a combo box with details", 'one', 'two', 'three', informative: nil, details: 'This is some details')
puts "answer:#{answer}"
answer = combo_box("This is a combo box with info & details", 'one', 'two', 'three', informative: 'This is informative', details: 'Details details details!')
puts "answer:#{answer}"
answer = combo_box("This is a combo box", 'one', 'two', 'three', text_color: 'blue', background_color: 'grey', font_size: 20, font_family: 'courier', details: "Some more stuff")
puts "answer:#{answer}"
answer = prompt("This is a test", text_color: 'blue', background_color: 'grey', font_size: 20, font_family: 'courier', informative: "Informative text", details: "Some more stuff")
puts "answer:#{answer}"
answer = prompt("This is a test", font_size: 30, details: "Some more stuff", informative: nil)
puts "answer:#{answer}"
answer = message_box('This is a message box', 'one', 'two', 'three', text_color: 'blue', background_color: 'grey', font_size: 20, font_family: 'courier', informative: "Informative stuff", details: "Some more stuff")
puts "answer:#{answer}"
answer = message_box('This is a message box', 'one', 'two', 'three', false, background_color: 'grey', details: "Some more stuff")
puts "answer:#{answer}"
answer = vertical_message_box('This is a message box', 'one', 'two', 'three', text_color: 'blue', background_color: 'grey', font_size: 20, font_family: 'courier', informative: "Informative stuff", details: "Some more stuff")
puts "answer:#{answer}"
answer = vertical_message_box('This is a message box', 'one', 'two', 'three', false, text_color: 'green')
puts "answer:#{answer}"
