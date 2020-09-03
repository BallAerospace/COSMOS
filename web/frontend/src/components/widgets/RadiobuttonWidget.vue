<template>
  <v-radio hide-details dense :label="label" :style="computedStyle"> </v-radio>
</template>

<script>
import Widget from './Widget'

export default {
  mixins: [Widget],
  data() {
    return {
      label: 'Radio'
    }
  },
  created() {
    this.label = this.parameters[0]
  }
}
</script>

<style lang="scss" scoped></style>
