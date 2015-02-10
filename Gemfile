# encoding: ascii-8bit

source 'https://rubygems.org'

gem 'ruby-termios', '~> 0.9' if RbConfig::CONFIG['target_os'] !~ /mswin|mingw|cygwin/i
group :development do
  gem 'wdm', '>= 0.1.0', :platforms => [:mswin, :mingw]
end
gemspec
