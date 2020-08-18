<template>
  <div ref="container" class="d-flex flex-row" :style="computedStyle">
    <LabelWidget :parameters="labelName" :settings="settings" />
    <LedWidget :parameters="parameters" :settings="settings" />
  </div>
</template>

<script>
import Widget from './Widget'
import LabelWidget from './LabelWidget.vue'
import LedWidget from './LedWidget.vue'

export default {
  mixins: [Widget],
  components: {
    LabelWidget,
    LedWidget
  },
  computed: {
    labelName() {
      // LabelWidget uses index 0 from the parameters prop
      // so create an array with the label text in the first position
      return [this.parameters[2] + ':']
    }
  }
}
</script>
