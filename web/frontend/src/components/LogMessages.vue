<template>
  <v-card>
    <v-card-title>
      Log Messages
      <v-spacer></v-spacer>
      <v-text-field
        v-model="search"
        append-icon="mdi-magnify"
        label="Search"
        single-line
        hide-details
        data-test="search-log-messages"
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
      height="45vh"
      data-test="log-messages"
    ></v-data-table>
  </v-card>
</template>

<script>
import * as ActionCable from 'actioncable'

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
        { text: 'Time', value: '@timestamp', width: 250 },
        { text: 'Severity', value: 'severity' },
        { text: 'Source', value: 'microservice_name' },
        { text: 'Message', value: 'log' }
      ],
      cable: ActionCable.Cable,
      subscription: ActionCable.Channel
    }
  },
  created() {
    this.cable = ActionCable.createConsumer('ws://localhost:7777/cable')
    this.subscription = this.cable.subscriptions.create(
      {
        channel: 'MessagesChannel',
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
  methods: {}
}
</script>

<style scoped></style>
