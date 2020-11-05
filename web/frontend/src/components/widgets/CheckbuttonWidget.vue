<template>
  <v-checkbox
    hide-details
    dense
    :label="label"
    v-model="value"
    :style="computedStyle"
  >
  </v-checkbox>
</template>

<script>
import Widget from './Widget'

export default {
  mixins: [Widget],
  data() {
    return {
      items: [],
      label: 'Checkbox',
      value: false,
    }
  },
  created() {
    // Look through the settings and see if we're a NAMED_WIDGET
    this.settings.forEach((setting) => {
      if (setting[0] === 'NAMED_WIDGET') {
        setting[2].setNamedWidget(setting[1], this)
      }
    })
    this.label = this.parameters[0]
  },
  methods: {
    checked() {
      return this.value
    },
  },
}
</script>

<style lang="scss" scoped></style>
