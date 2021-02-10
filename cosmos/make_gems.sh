# export VERSION= before running this
git checkout master
git pull
rbenv global 2.4.4
rake release VERSION=$VERSION
rake commit_release VERSION=$VERSION
mv *.gem ~/share/.
rbenv global jruby-9.1.12.0
gem build cosmos.gemspec
mv *.gem ~/share/.
