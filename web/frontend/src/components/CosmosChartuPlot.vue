<template>
  <div>
    <v-card @click.native="$emit('click')">
      <v-system-bar :class="selectedPlotId === id ? 'active' : 'inactive'">
        <v-spacer />
        <span>{{ title }}</span>
        <v-spacer />
        <v-icon v-if="calcFullSize" @click="collapseAll"
          >mdi-arrow-collapse</v-icon
        >
        <v-icon v-else @click="expandAll">mdi-arrow-expand</v-icon>
        <v-icon v-if="fullWidth" @click="collapseWidth"
          >mdi-arrow-collapse-horizontal</v-icon
        >
        <v-icon v-else @click="expandWidth">mdi-arrow-expand-horizontal</v-icon>
        <v-icon v-if="fullHeight" @click="collapseHeight"
          >mdi-arrow-collapse-vertical</v-icon
        >
        <v-icon v-else @click="expandHeight">mdi-arrow-expand-vertical</v-icon>
        <v-icon @click="minMaxTransition">mdi-window-minimize</v-icon>
        <v-icon @click="$emit('close-plot')">mdi-close-box</v-icon>
      </v-system-bar>
      <v-expand-transition>
        <div class="pa-1" id="chart" ref="chart" v-show="expand">
          <div :id="'chart' + id"></div>
          <div :id="'overview' + id"></div>
        </div>
      </v-expand-transition>
    </v-card>

    <v-dialog
      v-model="editPlot"
      @keydown.esc="editPlot = false"
      max-width="500"
    >
      <v-card class="pa-3">
        <v-card-title class="headline">Edit Plot</v-card-title>
        <v-text-field label="Title" v-model="title" hide-details></v-text-field>
        <v-text-field
          label="Min X"
          v-model="plotMinX"
          hide-details
        ></v-text-field>
        <v-text-field
          label="Max X"
          v-model="plotMaxX"
          hide-details
        ></v-text-field>
        <v-container fluid>
          <v-row v-for="(item, key) in items" :key="key">
            <v-col
              >{{ item.targetName }} {{ item.packetName }}
              {{ item.itemName }}</v-col
            >
            <v-btn color="error" @click="deleteItem(item)">Remove</v-btn>
          </v-row></v-container
        >
        <v-btn color="primary" @click="editPlot = false">Ok</v-btn>
      </v-card>
    </v-dialog>

    <v-menu
      v-if="editPlotMenu"
      v-model="editPlotMenu"
      :position-x="editPlotMenuX"
      :position-y="editPlotMenuY"
      absolute
      offset-y
    >
      <v-list>
        <v-list-item @click="editPlot = true">
          <v-list-item-title style="cursor: pointer"
            >Edit {{ title }}</v-list-item-title
          >
        </v-list-item>
      </v-list>
    </v-menu>

    <v-menu
      v-if="itemMenu"
      v-model="itemMenu"
      :position-x="itemMenuX"
      :position-y="itemMenuY"
      absolute
      offset-y
    >
      <v-list>
        <v-list-item @click="deleteItem(selectedItem)">
          <v-list-item-title style="cursor: pointer"
            >Delete {{ selectedItem.itemName }}</v-list-item-title
          >
        </v-list-item>
      </v-list>
    </v-menu>
  </div>
</template>

<script>
import * as ActionCable from 'actioncable'
import uPlot from 'uplot'
import bs from 'binary-search'

// TODO Is there a better way to import this ... maybe in the style section?
require('./../../node_modules/uplot/dist/uPlot.min.css')

export default {
  props: {
    id: {
      type: Number,
      required: true,
    },
    selectedPlotId: {
      type: Number,
      // Not required because we pass null
    },
    state: {
      type: String,
      required: true,
    },
    // start time in nanoseconds to start the plot
    // this allows multiple plots to be synchronized
    startTime: {
      type: Number,
    },
    secondsPlotted: {
      type: Number,
      required: true,
    },
    pointsSaved: {
      type: Number,
      required: true,
    },
    pointsPlotted: {
      type: Number,
      required: true,
    },
  },
  data() {
    return {
      active: true,
      expand: true,
      fullWidth: true,
      fullHeight: true,
      plot: null,
      editPlot: false,
      editPlotMenu: false,
      editPlotMenuX: 0,
      editPlotMenuY: 0,
      itemMenu: false,
      itemMenuX: 0,
      itemMenuY: 0,
      selectedItem: null,
      title: '',
      overview: null,
      data: null,
      plotMinX: '',
      plotMaxX: '',
      indexes: {},
      items: [],
      drawInterval: null,
      zoomChart: false,
      zoomOverview: false,
      cable: ActionCable.Cable,
      subscription: ActionCable.Channel,
      colors: [
        'blue',
        'red',
        'green',
        'darkorange',
        'purple',
        'cornflowerblue',
        'lime',
        'gold',
        'hotpink',
        'tan',
        'cyan',
        'peru',
        'maroon',
        'coral',
        'navy',
        'teal',
        'brown',
        'crimson',
        'lightblue',
        'black',
      ],
    }
  },
  computed: {
    calcFullSize() {
      return this.fullWidth || this.fullHeight
    },
  },
  created() {
    // Creating the cable can be done once, subscriptions come and go
    this.cable = ActionCable.createConsumer('ws://localhost:7777/cable')
    this.title = 'Plot ' + this.id
  },
  mounted() {
    // This code allows for temporary pulling in a patched uPlot
    // Also note you need to add 'async' before the mounted method for await
    // const plugin = document.createElement('script')
    // plugin.setAttribute(
    //   'src',
    //   'https://leeoniya.github.io/uPlot/dist/uPlot.iife.min.js'
    // )
    // plugin.async = true
    // document.head.appendChild(plugin)
    // await new Promise(r => setTimeout(r, 500)) // Allow the js to load

    // TODO: This is demo / performance code of multiple items with many data points
    // 10 items at 500,000 each renders immediately and uses 180MB in Chrome
    // Refresh still works, chrome is sluggish but once you pause it is very performant
    // 500,000 pts at 1Hz is 138.9hrs .. almost 6 days
    //
    // 10 items at 100,000 each is very performant ... 1,000,000 pts is Qt TlmGrapher default
    // 100,000 pts at 1Hz is 27.8hrs
    //
    // 100,000 takes 40ms, Chrome uses 160MB
    // this.data = []
    // const dataPoints = 100000
    // const items = 10
    // let pts = new Array(dataPoints)
    // let times = new Array(dataPoints)
    // let time = 1589398007
    // let series = [{}]
    // for (let i = 0; i < dataPoints; i++) {
    //   times[i] = time
    //   pts[i] = i
    //   time += 1
    // }
    // this.data.push(times)
    // for (let i = 0; i < items; i++) {
    //   this.data.push(pts.map(x => x + i))
    //   series.push({
    //     label: 'Item' + i,
    //     stroke: this.colors[i]
    //   })
    // }

    let chartOpts = {
      ...this.getSize('chart'),
      ...this.getScales(),
      ...this.getAxes('chart'),
      // series: series, // TODO: Uncomment with the performance code
      series: [
        {
          label: 'Time',
        },
      ],
      cursor: {
        drag: {
          x: true,
          y: false,
        },
        // Sync the cursor across plots so mouseovers are synced
        sync: {
          key: 'cosmos',
          // setSeries links plots so clicking an item to hide it also hides the other graph item
          // setSeries: true,
        },
      },
      hooks: {
        setScale: [
          (chart, key) => {
            if (key == 'x' && !this.zoomOverview && this.overview) {
              this.zoomChart = true
              let left = Math.round(
                this.overview.valToPos(chart.scales.x.min, 'x')
              )
              let right = Math.round(
                this.overview.valToPos(chart.scales.x.max, 'x')
              )
              this.overview.setSelect({ left, width: right - left })
              this.zoomChart = false
            }
          },
        ],
        ready: [
          (u) => {
            let clientX
            let clientY
            let canvas = u.root.querySelector('canvas')
            canvas.addEventListener('contextmenu', (e) => {
              e.preventDefault()
              this.editPlotMenuX = e.clientX
              this.editPlotMenuY = e.clientY
              this.editPlotMenu = true
            })
            let legend = u.root.querySelector('.u-legend')
            legend.addEventListener('contextmenu', (e) => {
              e.preventDefault()
              this.itemMenuX = e.clientX
              this.itemMenuY = e.clientY
              // Grab the closest series and then figure out which index it is
              let seriesEl = e.target.closest('.u-series')
              let seriesIdx = Array.prototype.slice
                .call(legend.childNodes)
                .indexOf(seriesEl)
              let series = u.series[seriesIdx]
              if (series.item) {
                this.selectedItem = series.item
                this.itemMenu = true
              }
              return false
            })
          },
        ],
      },
    }
    // console.time('chart')
    this.plot = new uPlot(
      chartOpts,
      this.data,
      document.getElementById('chart' + this.id)
    )

    const overviewOpts = {
      ...this.getSize('overview'),
      ...this.getScales(),
      ...this.getAxes('overview'),
      // series: series, // TODO: Uncomment with the performance code
      cursor: {
        y: false,
        points: {
          show: false, // TODO: This isn't working
        },
        drag: {
          setScale: false,
          x: true,
          y: false,
        },
      },
      legend: {
        show: false,
      },
      hooks: {
        setSelect: [
          (chart) => {
            if (!this.zoomChart) {
              this.zoomOverview = true
              let min = chart.posToVal(chart.select.left, 'x')
              let max = chart.posToVal(
                chart.select.left + chart.select.width,
                'x'
              )
              this.plot.setScale('x', { min, max })
              this.zoomOverview = false
            }
          },
        ],
      },
    }
    this.overview = new uPlot(
      overviewOpts,
      this.data,
      document.getElementById('overview' + this.id)
    )
    //console.timeEnd('chart')

    // Allow the charts to dynamically resize when the window resizes
    window.addEventListener('resize', this.handleResize)

    if (this.state !== 'stop') {
      this.subscribe()
    }
  },
  beforeDestroy() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    this.cable.disconnect()
    window.removeEventListener('resize', this.handleResize)
  },
  watch: {
    state: function (newState, oldState) {
      switch (newState) {
        case 'start':
          this.subscribe()
          break
        // case 'pause': Nothing to do here
        case 'stop':
          this.subscription.unsubscribe()
          break
      }
    },
    data: function (newData, oldData) {
      if (this.state !== 'start') {
        return
      }
      this.plot.setData(newData)
      this.overview.setData(newData)
      let max = newData[0][newData[0].length - 1]
      let ptsMin = newData[0][newData[0].length - this.pointsPlotted]
      let min = newData[0][0]
      if (min < max - this.secondsPlotted) {
        min = max - this.secondsPlotted
      }
      if (ptsMin > min) {
        min = ptsMin
      }
      this.plot.setScale('x', { min, max })
    },
    plotMinX: function (newVal, oldVal) {
      let val = parseFloat(newVal)
      if (!isNaN(val)) {
        this.plotMinX = val
      }
      this.setPlotRange()
    },
    plotMaxX: function (newVal, oldVal) {
      let val = parseFloat(newVal)
      if (!isNaN(val)) {
        this.plotMaxX = val
      }
      this.setPlotRange()
    },
  },
  methods: {
    handleResize() {
      // TODO: Should this method be throttled?
      this.plot.setSize(this.getSize('chart'))
      this.overview.setSize(this.getSize('overview'))
    },
    resize() {
      this.plot.setSize(this.getSize('chart'))
      this.overview.setSize(this.getSize('overview'))
      this.$emit('resize')
    },
    expandAll() {
      this.fullWidth = true
      this.fullHeight = true
      this.resize()
    },
    collapseAll() {
      this.fullWidth = false
      this.fullHeight = false
      this.resize()
    },
    expandWidth() {
      this.fullWidth = true
      this.resize()
    },
    collapseWidth() {
      this.fullWidth = false
      this.resize()
    },
    expandHeight() {
      this.fullHeight = true
      this.resize()
    },
    collapseHeight() {
      this.fullHeight = false
      this.resize()
    },
    minMaxTransition() {
      this.expand = !this.expand
      this.$emit('min-max-plot')
    },
    setPlotRange() {
      let pad = 0.1
      if (
        this.plotMinX ||
        this.plotMinX === 0 ||
        this.plotMaxX ||
        this.plotMaxX === 0
      ) {
        pad = 0
      }
      this.plot.scales.y.range = (u, dataMin, dataMax) => {
        let min = dataMin
        if (this.plotMinX || this.plotMinX === 0) {
          min = this.plotMinX
        }
        let max = dataMax
        if (this.plotMaxX || this.plotMaxX === 0) {
          max = this.plotMaxX
        }
        return uPlot.rangeNum(min, max, pad, true)
      }
    },
    subscribe() {
      this.subscription = this.cable.subscriptions.create(
        {
          channel: 'StreamingChannel',
          scope: 'DEFAULT',
        },
        {
          received: (data) => this.received(data),
          connected: () => {
            var items = []
            this.items.forEach((item) => {
              items.push(
                'TLM__' +
                  item.targetName +
                  '__' +
                  item.packetName +
                  '__' +
                  item.itemName +
                  '__CONVERTED'
              )
            })
            this.subscription.perform('add', {
              scope: 'DEFAULT',
              items: items,
              // startTime is either a valid time or null which means start now
              start_time: this.startTime,
              // No end_time because we want to continue until we stop
            })
          },
          // TODO: How should we handle server side disconnect
          disconnected: () => alert('disconnected'),
        }
      )
    },
    throttle(cb, limit) {
      var wait = false

      return () => {
        if (!wait) {
          requestAnimationFrame(cb)
          wait = true
          setTimeout(() => {
            wait = false
          }, limit)
        }
      }
    },
    getSize(type) {
      const viewWidth = Math.max(
        document.documentElement.clientWidth,
        window.innerWidth || 0
      )
      const viewHeight = Math.max(
        document.documentElement.clientHeight,
        window.innerHeight || 0
      )

      const chooser = document.getElementsByClassName('c-chooser')[0]
      let height = 100
      if (type === 'overview') {
        if (!this.fullHeight) {
          height = 0
        }
      } else {
        // Height of chart is viewportSize - chooser - overview - fudge factor
        height = viewHeight - chooser.clientHeight - height - 150
        if (!this.fullHeight) {
          height = height / 2.0 + 10 // 5px padding top and bottom
        }
      }
      let width = viewWidth - 120
      if (!this.fullWidth) {
        width = width / 2.0 - 10 // 5px padding left and right
      }
      return {
        width: width,
        height: height,
      }
    },
    getScales() {
      return {
        scales: {
          x: {
            range(u, dataMin, dataMax) {
              if (dataMin == null) return [1566453600, 1566497660]
              return [dataMin, dataMax]
            },
          },
          y: {
            range(u, dataMin, dataMax) {
              if (dataMin == null) return [-100, 100]
              return uPlot.rangeNum(dataMin, dataMax, 0.1, true)
            },
          },
        },
      }
    },
    getAxes(type) {
      let strokeColor = 'rgba(0, 0, 0, .1)'
      let axisColor = 'black'
      if (this.$vuetify.theme.dark) {
        strokeColor = 'rgba(255, 255, 255, .1)'
        axisColor = 'white'
      }
      return {
        axes: [
          {
            stroke: axisColor,
            grid: {
              show: true,
              stroke: strokeColor,
              width: 2,
            },
          },
          {
            size: 70, // This size supports values up to 99 million
            stroke: axisColor,
            grid: {
              show: type === 'overview' ? false : true,
              stroke: strokeColor,
              width: 2,
            },
          },
        ],
      }
    },
    addItem(item) {
      this.items.push(item)
      if (this.data === null) {
        this.data = [[]]
      }
      let index = this.data.length
      let color = this.colors.shift()
      this.plot.addSeries(
        {
          spanGaps: true,
          item: item,
          label: item.itemName,
          stroke: color,
          value: (self, rawValue) =>
            rawValue == null ? '--' : rawValue.toFixed(2),
        },
        index
      )
      this.overview.addSeries(
        {
          spanGaps: true,
          stroke: color,
        },
        index
      )
      let newData = Array(this.data[0].length)
      this.data.splice(index, 0, newData)

      let key =
        'TLM__' +
        item.targetName +
        '__' +
        item.packetName +
        '__' +
        item.itemName +
        '__CONVERTED'
      this.indexes[key] = index

      if (this.state !== 'stop') {
        this.subscription.perform('add', {
          scope: 'DEFAULT',
          items: [key],
          start_time: this.startTime, // this.data[0][0] * 1_000_000_000,
          // No end_time because we want to continue until we stop
        })
      }
    },
    async deleteItem(item) {
      let key =
        'TLM__' +
        item.targetName +
        '__' +
        item.packetName +
        '__' +
        item.itemName +
        '__CONVERTED'
      this.subscription.perform('remove', {
        scope: 'DEFAULT',
        items: [key],
      })
      const index = this.reorderIndexes(key)
      // Put back the color so it's available for new series
      this.colors.unshift(this.plot.series[index].stroke)
      this.items.splice(index - 1, 1)
      this.data.splice(index, 1)
      this.plot.delSeries(index)
      this.overview.delSeries(index)
      this.plot.setData(this.data)
      this.overview.setData(this.data)
    },
    reorderIndexes(key) {
      let index = this.indexes[key]
      delete this.indexes[key]
      for (var i in this.indexes) {
        if (this.indexes[i] > index) {
          this.indexes[i] -= 1
        }
      }
      return index
    },
    received(json_data) {
      // TODO: Shouldn't get errors but should we handle this every time?
      // if (json_data.error) {
      //   console.log(json_data.error)
      //   return
      // }
      let data = JSON.parse(json_data)
      for (let i = 0; i < data.length; i++) {
        let time = data[i].time / 1_000_000_000.0 // Time in seconds
        let length = data[0].length
        if (length == 0 || time > data[0][length - 1]) {
          // Nominal case - append new data to end
          for (let j = 0; j < this.data.length; j++) {
            this.data[j].push(null)
          }
          this.set_data_at_index(this.data[0].length - 1, time, data[i])
        } else {
          let index = bs(this.data[0], time, this.bs_comparator)
          if (index >= 0) {
            // Found the slot in the existing data
            this.set_data_at_index(index, time, data[i])
          } else {
            // Insert a new null slot at the ideal index
            let ideal_index = -index - 1
            for (let j = 0; j < this.data.length; j++) {
              this.data[j].splice(ideal_index, 0, null)
            }
            this.set_data_at_index(ideal_index, time, data[i])
          }
        }
      }
      // If we weren't passed a startTime notify grapher of our start
      if (this.startTime === null) {
        this.$emit('started', this.data[0][0] * 1_000_000_000)
      }
    },
    bs_comparator(element, needle) {
      return element - needle
    },
    set_data_at_index(index, time, new_data) {
      this.data[0][index] = time
      for (const [key, value] of Object.entries(new_data)) {
        if (key == 'time') {
          continue
        }
        let key_index = this.indexes[key]
        if (key_index) {
          let array = this.data[key_index]
          if (!value.raw) {
            array[index] = value
          } else {
            array[index] = null
          }
        }
      }
    },
  },
}
</script>

<style scoped>
.active {
  background-color: var(--v-secondary-base);
}
.inactive {
  background-color: var(--v-primary-base);
}
#chart {
  background-color: var(--v-tertiary-darken2);
}
#chart >>> .u-legend {
  text-align: left;
}
#chart >>> .u-inline {
  max-width: fit-content;
}
/* TODO: Get this to work with white theme, values would be 0 in white */
#chart >>> .u-select {
  background-color: rgba(255, 255, 255, 0.07);
}
</style>
