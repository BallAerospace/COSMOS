#!/bin/sh
set -e

ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-base-5.0.0.*.gem
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-cmdtlmserver-5.0.0.*.gem
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-limitsmonitor-5.0.0.*.gem
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-cmdsender-5.0.0.*.gem
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-scriptrunner-5.0.0.*.gem
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-packetviewer-5.0.0.*.gem
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-tlmviewer-5.0.0.*.gem
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-tlmgrapher-5.0.0.*.gem
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-dataextractor-5.0.0.*.gem
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-dataviewer-5.0.0.*.gem
ruby /cosmos/bin/cosmos load /cosmos/plugins/gems/cosmosc2-tool-admin-5.0.0.*.gem
