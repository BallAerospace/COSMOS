Dir.glob("*.gem").each do |file|
  system("gem push #{file}")
end