# encoding: ascii-8bit

source 'https://rubygems.org'

gem 'ruby-termios', '~> 0.9' if RbConfig::CONFIG['target_os'] !~ /mswin|mingw|cygwin/i
if ENV['COSMOS_DEVEL']
  gem 'cosmos', :path => ENV['COSMOS_DEVEL']
else
  gem 'cosmos'
end
