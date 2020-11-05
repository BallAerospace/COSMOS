<template>
  <v-text-field
    solo
    dense
    single-line
    hide-no-data
    hide-details
    v-model="value"
    :style="computedStyle"
  >
  </v-text-field>
</template>

<script>
import Widget from './Widget'

export default {
  mixins: [Widget],
  data() {
    return {
      value: null,
    }
  },
  // computed: {
  //   width() {
  //     return this.parameters[0] ? parseInt(this.parameters[0]) : 20
  //   }
  // },
  created() {
    // Look through the settings and see if we're a NAMED_WIDGET
    this.settings.forEach((setting) => {
      if (setting[0] === 'NAMED_WIDGET') {
        setting[2].setNamedWidget(setting[1], this)
      }
    })

    // TODO: Is this actually working or do we need the computed width above (see LedWidget for an example)
    if (this.parameters[0]) {
      this.settings.push(['WIDTH', parseInt(this.parameters[0])])
    }
    if (this.parameters[1]) {
      this.value = this.parameters[1]
    }
  },
  methods: {
    text() {
      return this.value
    },
  },
}
</script>

<style lang="scss" scoped></style>
