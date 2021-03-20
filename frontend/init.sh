#!/bin/bash
set -e

ruby /cosmos/bin/cosmos load /cosmos/plugins/cosmosc2-tool-base/cosmosc2-tool-base-5.0.0.*.gem
ruby /cosmos/bin/cosmos load /cosmos/plugins/packages/cosmosc2-tool-cmdtlmserver/cosmosc2-tool-cmdtlmserver-5.0.0.*.gem
ruby /cosmos/bin/cosmos load /cosmos/plugins/packages/cosmosc2-tool-limitsmonitor/cosmosc2-tool-limitsmonitor-5.0.0.*.gem
ruby /cosmos/bin/cosmos load /cosmos/plugins/packages/cosmosc2-tool-cmdsender/cosmosc2-tool-cmdsender-5.0.0.*.gem
ruby /cosmos/bin/cosmos load /cosmos/plugins/packages/cosmosc2-tool-scriptrunner/cosmosc2-tool-scriptrunner-5.0.0.*.gem
ruby /cosmos/bin/cosmos load /cosmos/plugins/packages/cosmosc2-tool-packetviewer/cosmosc2-tool-packetviewer-5.0.0.*.gem
ruby /cosmos/bin/cosmos load /cosmos/plugins/packages/cosmosc2-tool-tlmviewer/cosmosc2-tool-tlmviewer-5.0.0.*.gem
ruby /cosmos/bin/cosmos load /cosmos/plugins/packages/cosmosc2-tool-tlmgrapher/cosmosc2-tool-tlmgrapher-5.0.0.*.gem
ruby /cosmos/bin/cosmos load /cosmos/plugins/packages/cosmosc2-tool-dataextractor/cosmosc2-tool-dataextractor-5.0.0.*.gem
ruby /cosmos/bin/cosmos load /cosmos/plugins/packages/cosmosc2-tool-dataviewer/cosmosc2-tool-dataviewer-5.0.0.*.gem
ruby /cosmos/bin/cosmos load /cosmos/plugins/packages/cosmosc2-tool-admin/cosmosc2-tool-admin-5.0.0.*.gem
