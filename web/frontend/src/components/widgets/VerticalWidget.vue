<template>
  <div ref="container" class="d-flex flex-column">
    <component
      v-for="(widget, index) in widgets"
      :key="index"
      :is="widget.type"
      :parameters="widget.parameters"
      :settings="widget.settings"
      :widgets="widget.widgets"
    ></component>
  </div>
</template>

<script>
import Layout from './Layout'
export default {
  mixins: [Layout]
}
</script>
