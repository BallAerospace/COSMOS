<template>
  <v-container>
    <v-row no-gutters>
      <v-text-field
        width="200"
        dense
        outlined
        readonly
        label="Overall Limits State"
        :value="overallState"
        :class="textFieldClass"
      ></v-text-field>
    </v-row>
    <v-row no-gutters v-for="(item, index) in items" :key="index">
      <LabelvaluelimitsbarWidget
        v-if="item.limits"
        :parameters="item.parameters"
      ></LabelvaluelimitsbarWidget>
      <LabelvalueWidget v-else :parameters="item.parameters"></LabelvalueWidget>
    </v-row>
  </v-container>
</template>

<script>
import { CosmosApi } from '@/services/cosmos-api'
import LabelvalueWidget from '@/components/widgets/LabelvalueWidget'
import LabelvaluelimitsbarWidget from '@/components/widgets/LabelvaluelimitsbarWidget'

export default {
  components: {
    LabelvalueWidget,
    LabelvaluelimitsbarWidget,
  },
  data() {
    return {
      api: null,
      ignored: [
        // ['INST', 'HEALTH_STATUS', null],
        // ['INST2', 'HEALTH_STATUS', null],
        ['INST', 'MECH', 'SLRPNL1'],
        ['INST2', 'MECH', 'SLRPNL1'],
        ['INST', 'PARAMS', 'VALUE2'],
        ['INST2', 'PARAMS', 'VALUE2'],
        ['INST', 'PARAMS', 'VALUE4'],
        ['INST2', 'PARAMS', 'VALUE4'],
      ],
      overallState: null,
      items: [],
      itemList: [],
    }
  },
  computed: {
    textFieldClass() {
      if (this.overallState) {
        return 'textfield-' + this.overallState.toLowerCase()
      } else {
        return ''
      }
    },
  },
  created() {
    this.api = new CosmosApi()
    this.api.get_out_of_limits().then((items) => {
      for (const item of items) {
        this.itemList.push(item.slice(0, 3).join('__'))
        let itemInfo = { parameters: item.slice(0, 3) }
        if (item[3] == 'YELLOW' || item[3] == 'RED') {
          itemInfo['limits'] = false
        } else {
          itemInfo['limits'] = true
        }
        this.items.push(itemInfo)
      }
    })
  },

  methods: {
    handleMessages(messages) {
      for (let message of messages) {
        let item =
          message.target_name +
          '__' +
          message.packet_name +
          '__' +
          message.item_name
        if (this.itemList.includes(item)) {
          continue
        }
        let itemInfo = {
          parameters: [
            message.target_name,
            message.packet_name,
            message.item_name,
          ],
        }
        if (
          message.new_limits_state == 'YELLOW' ||
          message.new_limits_state == 'RED'
        ) {
          itemInfo['limits'] = false
        } else {
          itemInfo['limits'] = true
        }
        this.itemList.push(item)
        this.items.push(itemInfo)
      }
      this.api.get_overall_limits_state(this.ignored).then((state) => {
        this.overallState = state
      })
    },
  },
}
</script>

<style scoped>
.v-card {
  padding: 10px;
}
.textfield-green >>> .v-text-field__slot input {
  color: green;
}
.textfield-green >>> .v-text-field__slot label {
  color: green;
}
.textfield-yellow >>> .v-text-field__slot input {
  color: yellow;
}
.textfield-yellow >>> .v-text-field__slot label {
  color: yellow;
}
.textfield-red >>> .v-text-field__slot input {
  color: red;
}
.textfield-red >>> .v-text-field__slot label {
  color: red;
}
</style>
