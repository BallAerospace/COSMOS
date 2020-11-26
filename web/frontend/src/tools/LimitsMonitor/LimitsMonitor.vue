<template>
  <div>
    <app-nav :menus="menus" />
    <v-tabs v-model="curTab" fixed-tabs>
      <v-tab v-for="(tab, index) in tabs" :key="index">{{ tab }}</v-tab>
    </v-tabs>
    <v-tabs-items v-model="curTab">
      <v-tab-item :eager="true">
        <keep-alive>
          <limits-control ref="control"></limits-control>
        </keep-alive>
      </v-tab-item>
      <v-tab-item :eager="true">
        <keep-alive>
          <limits-events ref="events"></limits-events>
        </keep-alive>
      </v-tab-item>
    </v-tabs-items>
  </div>
</template>

<script>
import AppNav from '@/AppNav'
import { CosmosApi } from '@/services/cosmos-api'
import LimitsControl from '@/tools/LimitsMonitor/LimitsControl'
import LimitsEvents from '@/tools/LimitsMonitor/LimitsEvents'
import * as ActionCable from 'actioncable'

export default {
  components: {
    AppNav,
    LimitsControl,
    LimitsEvents,
  },
  data() {
    return {
      curTab: null,
      tabs: ['Limits', 'Log'],
      cable: ActionCable.Cable,
      subscription: ActionCable.Channel,
      menus: [
        {
          label: 'File',
          items: [
            {
              label: 'Show Ignored',
              command: () => {
                this.$refs.control.showIgnored()
              },
            },
          ],
        },
      ],
    }
  },
  created() {
    this.cable = ActionCable.createConsumer('ws://localhost:7777/cable')
    this.subscription = this.cable.subscriptions.create(
      {
        channel: 'LimitsEventsChannel',
        history_count: 1000,
        scope: 'DEFAULT',
      },
      {
        received: (data) => {
          const parsed = JSON.parse(data)
          this.$refs.control.handleMessages(parsed)
          this.$refs.events.handleMessages(parsed)
        },
      }
    )
  },
  destroyed() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    this.cable.disconnect()
  },
}
</script>
