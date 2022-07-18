<!--
# Copyright 2022 Ball Aerospace & Technologies Corp.
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

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved
-->

<template>
  <div ref="container" class="d-flex flex-column">
    <component
      v-on="$listeners"
      v-for="(widget, index) in widgets"
      :key="index"
      :is="widget.type"
      :target="widget.target"
      :parameters="widget.parameters"
      :settings="widget.settings"
      :widgets="widget.widgets"
      :name="widget.name"
    />
  </div>
</template>

<script>
import Layout from './Layout'
export default {
  mixins: [Layout],
}
</script>
