<template>
  <v-banner single-line>{{ labelText }}</v-banner>
</template>

<script>
import Widget from './Widget'

export default {
  mixins: [Widget],
  computed: {
    labelText() {
      return this.parameters[0]
    }
  }
}
</script>

<style lang="scss" scoped></style>
