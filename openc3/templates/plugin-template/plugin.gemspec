# encoding: ascii-8bit

# Create the overall gemspec
spec = Gem::Specification.new do |s|
  s.name = '<%= plugin_name %>'
  s.summary = 'OpenC3 <%= plugin_name %> plugin'
  s.description = <<-EOF
    <%= plugin_name %> plugin for deployment to OpenC3
  EOF
  s.license = 'AGPL-3.0-only'
  s.authors = ['Anonymous']
  s.email = ['name@domain.com']
  s.homepage = 'https://github.com/OpenC3/openc3'
  s.platform = Gem::Platform::RUBY

  time = Time.now.strftime("%Y%m%d%H%M%S")
  if ENV['VERSION']
    s.version = ENV['VERSION'].dup + ".#{time}"
  else
    s.version = '0.0.0' + ".#{time}"
  end
  s.files = Dir.glob("{targets,lib,procedures,tools,microservices}/**/*") + %w(Rakefile README.md plugin.txt)
end
