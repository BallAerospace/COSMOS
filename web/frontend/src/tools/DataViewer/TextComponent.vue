<template>
  <div>
    <v-textarea
      :rows="rowCount"
      id="text"
      hide-details
      readonly
      class="pa-2"
      :value="value"
    >
    </v-textarea>
  </div>
</template>

<script>
import { format } from 'date-fns'
import debounce from 'lodash/debounce'
import floor from 'lodash/floor'
import Component from './Component'
export default {
  mixins: [Component],
  data() {
    return {
      rowCount: 5
    }
  },
  created() {
    // TODO: Get actual data to put in here
    setInterval(() => {
      this.value +=
        '\n' +
        format(new Date(), 'yyyy-MM-dd HH:mm:ss') +
        ': More text to append'
      this.$nextTick(function() {
        let textarea = document.getElementById('text')
        textarea.scrollTop = textarea.scrollHeight
      })
    }, 1000)
  },
  mounted() {
    // Allow the output to dynamically resize when the window resizes
    window.addEventListener('resize', debounce(this.calcRows, 200))
    this.calcRows()
  },
  beforeDestroy() {
    window.removeEventListener('resize')
  },
  methods: {
    calcRows() {
      let height = Math.max(
        document.documentElement.clientHeight,
        window.innerHeight || 0
      )
      // TODO Fudget factor for header & footer, better way to calc this?
      height -= 200
      this.rowCount = floor(height / 24)
      if (this.rowCount < 5) {
        this.rowCount = 5
      }
    }
  }
}
</script>

<style lang="scss" scoped>
.v-textarea {
  font-family: 'Courier New', Courier, monospace;
}
</style>
