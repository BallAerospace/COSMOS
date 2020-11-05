<template>
  <image
    :href="calcHref"
    :x="calcX"
    :y="calcY"
    :width="calcWidth"
    :height="calcHeight"
  />
</template>

<script>
import Widget from './Widget'
import get from 'lodash/get'
import set from 'lodash/set'

export default {
  mixins: [Widget],
  data() {
    return {
      valueId: 0,
      imageLookup: {},
      defaultLookup: {},
    }
  },
  computed: {
    calcHref() {
      const value = this.$store.state.tlmViewerValues[0][this.valueId]
      const href = get(this.imageLookup, [value, 'img'], this.defaultLookup.img)
      if (href && href.includes('http')) {
        return href
      } else {
        return 'img/' + href
      }
    },
    calcX() {
      const value = this.$store.state.tlmViewerValues[0][this.valueId]
      return get(this.imageLookup, [value, 'x'], this.defaultLookup.x)
    },
    calcY() {
      const value = this.$store.state.tlmViewerValues[0][this.valueId]
      return get(this.imageLookup, [value, 'y'], this.defaultLookup.y)
    },
    calcWidth() {
      const value = this.$store.state.tlmViewerValues[0][this.valueId]
      return get(this.imageLookup, [value, 'width'], this.defaultLookup.width)
    },
    calcHeight() {
      const value = this.$store.state.tlmViewerValues[0][this.valueId]
      return get(this.imageLookup, [value, 'height'], this.defaultLookup.height)
    },
  },
  // Note Vuejs still treats this syncronously, but this allows us to dispatch
  // the store mutation and return the array index.
  // What this means practically is that future lifecycle hooks may not have valueId set.
  async created() {
    let theType = 'RAW'
    if (this.parameters[3]) {
      theType = this.parameters[3]
    }
    this.valueId = await this.$store.dispatch('tlmViewerAddItem', {
      target: this.parameters[0],
      packet: this.parameters[1],
      item: this.parameters[2],
      type: theType,
    })
    let width = '100%'
    if (this.parameters[7]) {
      width = this.parameters[7] + 'px'
    }
    let height = '100%'
    if (this.parameters[8]) {
      height = this.parameters[8] + 'px'
    }
    if (this.parameters[4]) {
      this.defaultLookup = {
        img: this.parameters[4],
        x: this.parameters[5],
        y: this.parameters[6],
        width: width,
        height: height,
      }
    }

    this.settings.forEach((setting) => {
      switch (setting[0]) {
        case 'IMAGE':
          set(this.imageLookup, setting[1], {
            img: setting[2],
            x: setting[3],
            y: setting[4],
            width: setting[5],
            height: setting[6],
          })
          break
      }
    })
  },
}
</script>
