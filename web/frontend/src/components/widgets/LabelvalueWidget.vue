<template>
  <div ref="container" class="d-flex flex-row">
    <LabelWidget
      :parameters="labelName"
      :settings="settings"
      :style="computedStyle"
      :widgetIndex="0"
    />
    <ValueWidget
      :parameters="parameters"
      :settings="settings"
      :style="computedStyle"
      :widgetIndex="1"
    />
  </div>
</template>

<script>
import Widget from './Widget'
import LabelWidget from './LabelWidget.vue'
import ValueWidget from './ValueWidget.vue'

export default {
  mixins: [Widget],
  components: {
    LabelWidget,
    ValueWidget,
  },
  computed: {
    labelName() {
      // LabelWidget uses index 0 from the parameters prop
      // so create an array with the label text in the first position
      return [this.parameters[2] + ':']
    },
  },
}
</script>
