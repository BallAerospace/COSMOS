<template>
  <div ref="container" class="d-flex flex-column" :style="computedStyle">
    <LimitscolumnWidget
      :parameters="limitsColumnParameters"
      :settings="settings"
      :widgetIndex="0"
    />
    <ValueWidget
      :parameters="parameters"
      :settings="settings"
      :widgetIndex="1"
    />
  </div>
</template>

<script>
import ValueWidget from './ValueWidget.vue'
import LimitscolumnWidget from './LimitscolumnWidget.vue'
import Widget from './Widget'

export default {
  mixins: [Widget],
  components: {
    ValueWidget,
    LimitscolumnWidget,
  },
  created() {
    this.settings.push(['WIDTH', '100'])
  },
  computed: {
    limitsColumnParameters() {
      return [
        this.parameters[0],
        this.parameters[1],
        this.parameters[2],
        'CONVERTED',
      ]
    },
  },
}
</script>
