<!--
# Copyright 2022 Ball Aerospace & Technologies Corp.
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

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved
-->

<!-- OBE by Graph.vue which uses uPlot -->
<template>
  <div>
    <canvas id="chart" />
  </div>
</template>

<script>
import Chart from 'chart.js'
import 'chartjs-adapter-luxon'
import { DateTime } from 'luxon'
import Cable from '../services/cable.js'

export default {
  props: {
    secondsGraphed: {
      type: Number,
      required: true,
    },
    pointsSaved: {
      type: Number,
      required: true,
    },
    pointsGraphed: {
      type: Number,
      required: true,
    },
  },
  data() {
    return {
      chart: null,
      data: {
        datasets: [],
      },
      items: [],
      running: false,
      paused: false,
      drawInterval: null,
      cable: new Cable(),
      subscription: null,
      colors: [
        'blue',
        'red',
        'green',
        'darkorange',
        'gold',
        'purple',
        'hotpink',
        'lime',
        'cornflowerblue',
        'brown',
        'coral',
        'crimson',
        'indigo',
        'tan',
        'lightblue',
        'cyan',
        'peru',
        'maroon',
        'orange',
        'navy',
        'teal',
        'black',
      ],
    }
  },
  mounted() {
    // TODO: This is demo / performance code of multiple items with many data points
    // 10000 pts takes 1.7s, Chrome consume 530MB mem
    // 20000 pts takes 3.6s, Chrome consumes 1GB
    // 40000 pts takes 8.2s, Chrome consumes 1.8GB
    const dataPoints = 40000
    const items = 10
    let time = 1589398007
    let data = []
    for (let i = 0; i < dataPoints; i++) {
      data.push({ x: DateTime.fromSeconds(time).toISO(), y: i })
      time += 1
    }
    for (let i = 0; i < items; i++) {
      this.data.datasets.push({
        label: 'Item' + i,
        data: data.slice(),
        fill: false,
        borderColor: this.colors[i],
        backgroundColor: this.colors[i],
      })
    }

    //console.time('chart')
    this.chart = new Chart('chart', {
      type: 'line',
      data: this.data,
      options: {
        spanGaps: true, // enable for all datasets
        animation: false,
        scales: {
          x: {
            type: 'time',
            display: true,
          },
        },
        elements: {
          line: {
            tension: 0, // disables bezier curves
            fill: false,
            stepped: false,
            borderDash: [],
          },
          point: {
            radius: 0, // default to disabled in all datasets
          },
        },
      },
    })
    //console.timeEnd('chart')
  },
  destroyed() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    this.cable.disconnect()
  },
  methods: {
    subscribe() {
      this.cable
        .createSubscription('PreidentifiedChannel', null, {
          received: (data) => this.received(data),
          connected: () => {
            this.items.forEach((item) => {
              this.subscription.perform('add_item', {
                item:
                  item.targetName + ' ' + item.packetName + ' ' + item.itemName,
              })
            })
          },
          // TODO: How should we handle server side disconnect
          //disconnected: () => alert('disconnected')
        })
        .then((subscription) => {
          this.subscription = subscription
        })
    },
    start() {
      if (this.running || this.items.length === 0) {
        return
      }
      this.subscribe()
      this.running = true
    },
    stop() {
      if (!this.running) {
        return
      }
      this.running = false
      this.subscription.unsubscribe()
    },
    pauseResume() {
      if (this.paused) {
        this.drawGraph()
      } else {
        clearInterval(this.drawInterval)
      }
      this.paused = !this.paused
    },
    addItem(item) {
      this.items.push(item)
      this.data.datasets.push({
        label: item.targetName + ' ' + item.packetName + ' ' + item.itemName,
        data: [],
        borderColor: this.colors[this.data.datasets.length], // line color
        backgroundColor: this.colors[this.data.datasets.length], // point color
      })

      if (this.running) {
        this.subscription.perform('add_item', {
          item: item.targetName + ' ' + item.packetName + ' ' + item.itemName,
        })
      }
    },
    received(data) {
      var i = 0
      while (i < data.length) {
        this.data.datasets[i].data.push({
          x: DateTime.fromSeconds(data[i]['x']).toISO(),
          y: data[i]['y'],
        })
        i++
      }
    },
  },
}
</script>
