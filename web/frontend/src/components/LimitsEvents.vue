<template>
  <v-card class="card-height">
    <v-card-title>
      Limits Events
      <v-spacer></v-spacer>
      <v-text-field
        v-model="search"
        append-icon="mdi-magnify"
        label="Search"
        single-line
        hide-details
      ></v-text-field>
    </v-card-title>
    <v-data-table
      :headers="headers"
      :items="data"
      :search="search"
      calculate-widths
      disable-pagination
      hide-default-footer
      multi-sort
      dense
      :height="calcTableHeight()"
    >
      <template v-slot:item.time_nsec="{ item }">
        <span>{{ formatDate(item.time_nsec) }}</span>
      </template>
      <template v-slot:item.message="{ item }">
        <span :class="getColorClass(item.message)">{{ item.message }}</span>
      </template>
    </v-data-table>
  </v-card>
</template>

<script>
import * as ActionCable from 'actioncable'
import { toDate, format } from 'date-fns'

export default {
  props: {
    history_count: {
      type: Number,
      default: 1000
    }
  },
  data() {
    return {
      data: [],
      search: '',
      headers: [
        { text: 'Time', value: 'time_nsec', width: 250 },
        { text: 'Message', value: 'message' }
      ],
      cable: ActionCable.Cable,
      subscription: ActionCable.Channel
    }
  },
  created() {
    this.cable = ActionCable.createConsumer('ws://localhost:7777/cable')
    this.subscription = this.cable.subscriptions.create(
      {
        channel: 'LimitsEventsChannel',
        history_count: this.history_count,
        scope: 'DEFAULT'
      },
      {
        received: data => {
          let messages = JSON.parse(data)
          for (let i = 0; i < messages.length; i++) {
            this.data.unshift(messages[i])
          }
          if (this.data.length > this.history_count) {
            this.data.length = this.history_count
          }
        }
      }
    )
  },
  destroyed() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    this.cable.disconnect()
  },
  methods: {
    formatDate(date) {
      return format(
        toDate(parseInt(date) / 1_000_000),
        'yyyy-MM-dd HH:MM:ss.SSS'
      )
    },
    getColorClass(message) {
      if (message.includes('GREEN')) {
        return 'cosmos-green'
      } else if (message.includes('YELLOW')) {
        return 'cosmos-yellow'
      } else if (message.includes('RED')) {
        return 'cosmos-red'
      } else if (message.includes('BLUE')) {
        return 'cosmos-blue'
      }
      if (this.$vuetify.theme.dark) {
        return 'cosmos-white'
      } else {
        return 'cosmos-black'
      }
    },
    calcTableHeight() {
      // TODO: 250 is a magic number but seems to work well
      return window.innerHeight - 250
    }
  }
}
</script>

<style lang="scss" scoped>
.card-height {
  // TODO: 150 is a magic number but seems to work well
  // Can this be calculated by the size of the table search box?
  height: calc(100vh - 150px);
}
</style>
