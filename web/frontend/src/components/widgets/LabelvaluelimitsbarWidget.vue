<template>
  <div
    ref="container"
    class="d-flex flex-row"
    :style="[defaultStyle, computedStyle]"
  >
    <LabelvalueWidget :parameters="parameters" :settings="settings" />
    <LimitsbarWidget
      :parameters="limitsBarParameters"
      :settings="settings"
      :widgetIndex="3"
    />
  </div>
</template>

<script>
import LabelvalueWidget from './LabelvalueWidget.vue'
import LimitsbarWidget from './LimitsbarWidget.vue'
import Widget from './Widget'

export default {
  mixins: [Widget],
  components: {
    LabelvalueWidget,
    LimitsbarWidget,
  },
  data() {
    return {
      overallWidth: '300px',
    }
  },
  created() {
    // Determine if any sub-setting widths have been given
    // If so calculate the overall width, if not the default will be used
    let width = 0
    this.settings.forEach((setting) => {
      if (setting[1] === 'WIDTH') {
        width += parseInt(setting[2])
      }
    })
    if (width != 0) {
      this.overallWidth = width + 'px'
    }
  },
  computed: {
    limitsBarParameters() {
      return [
        this.parameters[0],
        this.parameters[1],
        this.parameters[2],
        'CONVERTED',
      ]
    },
    defaultStyle() {
      return {
        width: this.overallWidth,
      }
    },
  },
}
</script>
