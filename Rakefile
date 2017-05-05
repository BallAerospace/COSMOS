require "fileutils"
require "bundler/setup"

"build website"
task :build do
  puts "## Pulling any updates"
  system "git co website"
  system "git pull"
  puts "## Building website"
  system "jekyll build"
  system "git add -A"
  system "git diff --cached"
  puts "\n\nReview diff and commit with 'git commit -m \"Message\"'"
  puts "Then push with 'git push'"
end

"deploy website/_site to github pages"
task :deploy do
  puts "## Deploying website/_site to Github Pages "
  system "git co gh-pages"
  system "git co website -- _site"
  FileUtils.cp_r "_site/.", "."
  FileUtils.rm_r "_site"
  system "git add -A"
  system "git commit -m \"Deploying website/_site at #{Time.now}\""
  system "git push"
  system "git co website"
end
