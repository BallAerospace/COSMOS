<template>
  <v-btn class="ma-1" color="primary" :style="computedStyle" @click="onClick">{{
    buttonText
  }}</v-btn>
</template>

<script>
import { CosmosApi } from '@/services/cosmos-api'
import Widget from './Widget'

export default {
  mixins: [Widget],
  data() {
    return {
      api: null
    }
  },
  computed: {
    buttonText() {
      return this.parameters[0]
    },
    eval() {
      return this.parameters[1]
    }
  },
  created() {
    this.api = new CosmosApi()
  },
  methods: {
    onClick() {
      const lines = this.eval.split(';')
      lines.forEach(line => {
        console.log(line.trim())
        // TODO: Expose the COSMOS apis as global functions so eval will work
        eval(line.trim())
        // const cmd = this.convertLine(line)
        // this.api[cmd.method](cmd.target, cmd.packet, cmd.params)
      })
    }
    // convertLine(line) {
    //   let cmd = {}
    //   let parts
    //   parts = line.split('(')
    //   cmd.method = parts[0]
    //   parts = parts[1].slice(1, -2)
    //   parts = parts.split(' with ')
    //   let tgtPkt = parts[0].split(' ')
    //   cmd.target = tgtPkt[0].trim()
    //   cmd.packet = tgtPkt[1].trim()
    //   cmd.params = {}
    //   parts[1].split(',').forEach(param => {
    //     let keyValue = param.trim().split(' ')
    //     cmd.params[keyValue[0]] = keyValue[1]
    //   })
    //   console.log(cmd)
    //   return cmd
    // }
  }
}
</script>

<style lang="scss" scoped></style>
