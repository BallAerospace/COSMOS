require "fileutils"
require "bundler/setup"

"build website"
task :build do
  puts "## Building website"
  puts "## Pulling any updates"
  system "git co website"
  system "git pull"
  system "jekyll build"
  system "git add -A"
  system "git diff --cached"
  puts "\nReview diff and commit with 'git commit -m \"Message\"'"
  puts "Then push with 'git push'"
end

"deploy website to github pages"
task :deploy do
  puts "## Deploying website to Github Pages "
  puts "## Pulling any updates from Github Pages "
  system "git co gh-pages"
  system "git pull"
  system "git co website -- _site"
  FileUtils.cp_r "_site/.", "."
  FileUtils.rm_r "_site"
  system "git add -A"
  system "git diff --cached"
  puts "Review diff and commit with 'git commit -m \"Message\"'"
  puts "Then push with 'git push'"
end
