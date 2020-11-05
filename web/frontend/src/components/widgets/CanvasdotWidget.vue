<template>
  <circle
    :cx="parameters[0]"
    :cy="parameters[1]"
    :r="parameters[3]"
    :fill="parameters[2]"
  />
</template>

<script>
import Widget from './Widget'
export default {
  mixins: [Widget],
}
</script>
