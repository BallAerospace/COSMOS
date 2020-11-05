<template>
  <v-radio-group
    hide-details
    dense
    v-model="selectedIndex"
    :style="computedStyle"
  >
    <component
      v-for="(widget, index) in widgets"
      :key="index"
      :is="widget.type"
      :parameters="widget.parameters"
      :settings="widget.settings"
    ></component>
  </v-radio-group>
</template>

<script>
import Layout from './Layout'

export default {
  mixins: [Layout],
  data() {
    return {
      selectedIndex: 0,
    }
  },
  created() {
    // Look through the settings and see if we're a NAMED_WIDGET
    this.settings.forEach((setting) => {
      if (setting[0] === 'NAMED_WIDGET') {
        setting[2].setNamedWidget(setting[1], this)
      }
    })
    if (this.parameters[0]) {
      this.selectedIndex = parseInt(this.parameters[0])
    }
  },
  methods: {
    selected() {
      return this.selectedIndex
    },
  },
}
</script>

<style lang="scss" scoped></style>
