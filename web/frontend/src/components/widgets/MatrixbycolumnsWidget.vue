<template>
  <v-container class="pa-0">
    <v-row
      no-gutters
      v-for="(chunk, rindex) in widgetChunks"
      :key="'r' + rindex"
    >
      <v-col v-for="(widget, cindex) in chunk" :key="'c' + cindex">
        <component
          :is="widget.type"
          :parameters="widget.parameters"
          :settings="widget.settings"
          :widgets="widget.widgets"
        />
      </v-col>
    </v-row>
  </v-container>
</template>

<script>
import Layout from './Layout'
import _ from 'lodash'
export default {
  mixins: [Layout],
  computed: {
    columns() {
      return parseInt(this.parameters[0])
    },
    widgetChunks() {
      return _.chunk(this.widgets, this.columns)
    }
  }
}
</script>
