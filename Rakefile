require "fileutils"
require "bundler/setup"

"build website"
task :build do
  puts "## Pulling any updates"
  sh "git checkout website"
  sh "git pull"
  puts "## Building website"
  sh "jekyll build"
  sh "git add _site/*"
  puts "\n\nAll of _site has been added to the git commit."
  puts "Add additional source files, review the diff, and commit with 'git commit -m \"Message\"'"
  puts "Then push with 'git push'"
end

"deploy website/_site to github pages"
task :deploy do
  puts "## Deploying website/_site to Github Pages "
  sh "git checkout gh-pages"
  sh "git pull"
  sh "git checkout website -- _site"
  FileUtils.cp_r "_site/.", "."
  FileUtils.rm_r "_site"
  sh "git add -A"
  sh "git commit -m \"Deploying website/_site at #{Time.now}\""
  sh "git push"
  sh "git checkout website"
end
