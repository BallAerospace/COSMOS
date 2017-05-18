require "fileutils"
require "bundler/setup"

"build website"
task :build do
  puts "## Pulling any updates"
  system "git checkout website"
  system "git pull"
  puts "## Building website"
  system "jekyll build"
  system "git add _site/*"
  puts "\n\nAll of _site has been added to the git commit."
  puts "Add additional source files, review the diff, and commit with 'git commit -m \"Message\"'"
  puts "Then push with 'git push'"
end

"deploy website/_site to github pages"
task :deploy do
  puts "## Deploying website/_site to Github Pages "
  system "git checkout gh-pages"
  system "git pull"
  system "git checkout website -- _site"
  FileUtils.cp_r "_site/.", "."
  FileUtils.rm_r "_site"
  system "git add -A"
  system "git commit -m \"Deploying website/_site at #{Time.now}\""
  system "git push"
  system "git checkout website"
end
