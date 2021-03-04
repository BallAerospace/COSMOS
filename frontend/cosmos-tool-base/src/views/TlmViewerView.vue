<!--
# Copyright 2021 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder
-->

<template>
  <TlmViewer />
</template>

<script>
// @ is an alias to /src
import TlmViewer from '@/tools/TlmViewer/TlmViewer'
export default {
  name: 'TlmViewerView',
  mounted() {
    document.title = 'Telemetry Viewer: Cosmos'
  },
  components: {
    TlmViewer,
  },
}
</script>
