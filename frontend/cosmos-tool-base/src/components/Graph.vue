<!--
# Copyright 2021 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder
-->

<template>
  <div>
    <div :id="'chart' + id"></div>
    <div :id="'overview' + id"></div>
  </div>
</template>

<script>
import uPlot from 'uplot'
import { toDate, format, getTime } from 'date-fns'

// TODO Is there a better way to import this ... maybe in the style section?
require('./../../node_modules/uplot/dist/uPlot.min.css')

export default {
  components: {
  },
  props: {
    data: {
      type: Array,
      require: true,
    }
  },
  data() {
    return {
      id: Math.floor(Math.random() * 100000000),
      fullWidth: true,
      fullHeight: true,
      graph: null,
      overview: null,
      graphMinX: '',
      graphMaxX: '',
      indexes: {},
      items: [
        {
          itemName: 'TEMP1',
          packetName: 'HEALTH_STATUS',
          targetName: 'INST',
          valueType: 'CONVERTED'
        }
      ],
      drawInterval: null,
      zoomChart: false,
      zoomOverview: false,
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

  },
  mounted() {
    const chartSeries = this.items.map((item, index) => {
      return {
        spanGaps: true,
        item: item,
        label: item.itemName,
        stroke: this.colors[index],
        value: (self, rawValue) =>
          rawValue == null ? '--' : rawValue.toFixed(2),
      }
    })
    console.log('chartSeries', chartSeries)
    const chartOpts = {
      ...this.getSize('chart'),
      ...this.getScales(),
      ...this.getAxes('chart'),
      series: [
        {
          label: 'Time',
          value: (u, v) =>
            // Convert the unix timestamp into a formatted date / time
            v == null ? '--' : format(toDate(v * 1000), 'yyyy-MM-dd HH:mm:ss'),
        },
        ...chartSeries
      ],
      cursor: {
        drag: {
          x: true,
          y: false,
        },
        // Sync the cursor across graphs so mouseovers are synced
        sync: {
          key: 'cosmos',
          // setSeries links graphs so clicking an item to hide it also hides the other graph item
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
            let canvas = u.root.querySelector('canvas')
            canvas.addEventListener('contextmenu', (e) => {
              e.preventDefault()
              this.editGraphMenuX = e.clientX
              this.editGraphMenuY = e.clientY
              this.editGraphMenu = true
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
    this.graph = new uPlot(
      chartOpts,
      this.data,
      document.getElementById('chart' + this.id)
    )

    const overviewSeries = this.items.map((item, index) => {
      return {
        spanGaps: true,
        stroke: this.colors[index],
      }
    })
    console.log('overviewSeries', overviewSeries)
    const overviewOpts = {
      ...this.getSize('overview'),
      ...this.getScales(),
      ...this.getAxes('overview'),
      series: [
        ...overviewSeries
      ],
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
              this.graph.setScale('x', { min, max })
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

    // Allow the charts to dynamically resize when the window resizes
    window.addEventListener('resize', this.handleResize)
  },
  beforeDestroy() {
    window.removeEventListener('resize', this.handleResize)
  },
  watch: {
    data: function (newData, oldData) {
      this.graph.setData(newData)
      this.overview.setData(newData)
      let max = newData[0][newData[0].length - 1]
      let ptsMin = newData[0][newData[0].length - this.pointsGraphed]
      let min = newData[0][0]
      if (min < max - this.secondsGraphed) {
        min = max - this.secondsGraphed
      }
      if (ptsMin > min) {
        min = ptsMin
      }
      this.graph.setScale('x', { min, max })
    },
    graphMinX: function (newVal, oldVal) {
      let val = parseFloat(newVal)
      if (!isNaN(val)) {
        this.graphMinX = val
      }
      this.setGraphRange()
    },
    graphMaxX: function (newVal, oldVal) {
      let val = parseFloat(newVal)
      if (!isNaN(val)) {
        this.graphMaxX = val
      }
      this.setGraphRange()
    },
  },
  methods: {
    handleResize() {
      // TODO: Should this method be throttled?
      this.graph.setSize(this.getSize('chart'))
      this.overview.setSize(this.getSize('overview'))
    },
    resize() {
      this.graph.setSize(this.getSize('chart'))
      this.overview.setSize(this.getSize('overview'))
      this.$emit('resize', this.id)
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
      this.$emit('min-max-graph', this.id)
    },
    setGraphRange() {
      let pad = 0.1
      if (
        this.graphMinX ||
        this.graphMinX === 0 ||
        this.graphMaxX ||
        this.graphMaxX === 0
      ) {
        pad = 0
      }
      this.graph.scales.y.range = (u, dataMin, dataMax) => {
        let min = dataMin
        if (this.graphMinX || this.graphMinX === 0) {
          min = this.graphMinX
        }
        let max = dataMax
        if (this.graphMaxX || this.graphMaxX === 0) {
          max = this.graphMaxX
        }
        return uPlot.rangeNum(min, max, pad, true)
      }
    },
    getSize(type) {
      // const viewWidth = Math.max(
      //   document.documentElement.clientWidth,
      //   window.innerWidth || 0
      // )
      // const viewHeight = Math.max(
      //   document.documentElement.clientHeight,
      //   window.innerHeight || 0
      // )

      // const chooser = document.getElementsByClassName('c-chooser')[0]
      // let height = 100
      // if (type === 'overview') {
      //   if (!this.fullHeight) {
      //     height = 0
      //   }
      // } else if (chooser) {
      //   // Height of chart is viewportSize - chooser - overview - fudge factor (primarily padding)
      //   height = viewHeight - chooser.clientHeight - height - 190
      //   if (!this.fullHeight) {
      //     height = height / 2.0 + 10 // 5px padding top and bottom
      //   }
      // }
      // let width = viewWidth - 120
      // if (!this.fullWidth) {
      //   width = width / 2.0 - 10 // 5px padding left and right
      // }
      return {
        width: 400,
        height: type === 'overview' ? 100 : 300,
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
  },
}
</script>

<style scoped>
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
