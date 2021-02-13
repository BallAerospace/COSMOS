require "rubygems"
require "geminabox"

Geminabox.rubygems_proxy = true
Geminabox.allow_remote_failure = true
Geminabox.data = "/data"

run Geminabox::Server
