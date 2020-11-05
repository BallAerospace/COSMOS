<template>
  <span class="text-h5 text-center pa-1 mt-1 label" :style="computedStyle">{{
    labelText
  }}</span>
</template>

<script>
import Widget from './Widget'

export default {
  mixins: [Widget],
  computed: {
    labelText() {
      return this.parameters[0]
    },
  },
}
</script>

<style lang="scss" scoped></style>
