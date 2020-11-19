<template>
  <div ref="container" class="d-flex flex-column" :style="computedStyle">
    <LabelWidget
      :parameters="[parameters[2]]"
      :settings="settings"
      :widgetIndex="0"
    />
    <LimitscolumnWidget
      :parameters="limitsColumnParameters"
      :settings="settings"
      :widgetIndex="1"
    />
    <ValueWidget
      :parameters="parameters"
      :settings="settings"
      :widgetIndex="2"
    />
  </div>
</template>

<script>
import LabelWidget from './LabelWidget.vue'
import ValueWidget from './ValueWidget.vue'
import LimitscolumnWidget from './LimitscolumnWidget.vue'
import Widget from './Widget'

export default {
  mixins: [Widget],
  components: {
    LabelWidget,
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
