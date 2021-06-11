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
    <top-bar :menus="menus" :title="title" />

    <target-packet-item-chooser
      :initialTargetName="this.$route.params.target"
      :initialPacketName="this.$route.params.packet"
      @on-set="commandChanged($event)"
      @click="buildCmd($event)"
      :disabled="sendDisabled"
      buttonText="Send"
      mode="cmd"
    />

    <v-card v-if="rows.length != 0">
      <v-card-title>
        Parameters
        <v-spacer />
        <v-text-field
          v-model="search"
          append-icon="$astro-search"
          label="Search"
          single-line
          hide-details
        />
      </v-card-title>
      <v-data-table
        :headers="headers"
        :items="rows"
        :search="search"
        calculate-widths
        disable-pagination
        hide-default-footer
        multi-sort
        dense
        @contextmenu:row="showContextMenu"
      >
        <template v-slot:item.val_and_states="{ item }">
          <command-parameter-editor
            v-model="item.val_and_states"
            :statesInHex="statesInHex"
          />
        </template>
      </v-data-table>
    </v-card>
    <div class="ma-3">Status: {{ status }}</div>
    <div class="mt-3">
      Command History: (Pressing Enter on the line re-executes the command)
    </div>
    <v-textarea
      ref="history"
      :value="history"
      solo
      dense
      hide-details
      data-test="sender-history"
      @keydown.enter="historyEnter($event)"
      :background-color="getBackgroundColor()"
    />

    <v-menu
      v-model="contextMenuShown"
      :position-x="x"
      :position-y="y"
      absolute
      offset-y
    >
      <v-list>
        <v-list-item
          v-for="(item, index) in contextMenuOptions"
          :key="index"
          @click.stop="item.action"
        >
          <v-list-item-title>{{ item.title }}</v-list-item-title>
        </v-list-item>
      </v-list>
    </v-menu>
    <details-dialog
      :targetName="targetName"
      :packetName="commandName"
      :itemName="parameterName"
      :type="'cmd'"
      v-model="viewDetails"
    />

    <v-dialog v-model="displayErrorDialog" max-width="300">
      <v-card class="pa-3">
        <v-card-title class="headline">Error</v-card-title>
        <v-card-text>{{ status }}</v-card-text>
        <v-btn color="primary" @click="displayErrorDialog = false">Ok</v-btn>
      </v-card>
    </v-dialog>

    <v-dialog v-model="displaySendHazardous" max-width="300">
      <v-card class="pa-3">
        <v-card-title class="headline">Hazardous</v-card-title>
        <v-card-text>
          Warning: Command {{ targetName }} {{ commandName }} is Hazardous.
          Send?
        </v-card-text>
        <v-btn @click="sendHazardousCmd" class="primary mr-4">Yes</v-btn>
        <v-btn @click="cancelHazardousCmd" class="primary">No</v-btn>
      </v-card>
    </v-dialog>

    <v-dialog v-model="displaySendRaw" max-width="400">
      <v-card>
        <v-card-title class="headline">Send Raw</v-card-title>
        <v-container>
          <v-row no-gutters>
            <v-col>Interface:</v-col>
            <v-col>
              <v-select
                solo
                hide-details
                dense
                :items="interfaces"
                item-text="label"
                item-value="value"
                v-model="selectedInterface"
              />
            </v-col>
          </v-row>
          <v-row no-gutters>
            <v-col>Filename:</v-col>
            <v-col>
              <input type="file" @change="selectRawCmdFile($event)" />
            </v-col>
          </v-row>
          <v-row>
            <v-col>
              <v-btn @click="cancelRawCmd" class="primary" block>Cancel</v-btn>
            </v-col>
            <v-col>
              <v-btn @click="sendRawCmd" class="primary" block>Ok</v-btn>
            </v-col>
          </v-row>
        </v-container>
      </v-card>
    </v-dialog>
  </div>
</template>

<script>
import TargetPacketItemChooser from '@cosmosc2/tool-common/src/components/TargetPacketItemChooser'
import CommandParameterEditor from '@/tools/CommandSender/CommandParameterEditor'
import { CosmosApi } from '@cosmosc2/tool-common/src/services/cosmos-api'
import DetailsDialog from '@cosmosc2/tool-common/src/components/DetailsDialog'
import TopBar from '@cosmosc2/tool-common/src/components/TopBar'
import 'sprintf-js'
export default {
  components: {
    DetailsDialog,
    TargetPacketItemChooser,
    CommandParameterEditor,
    TopBar,
  },
  data() {
    return {
      title: 'Command Sender',
      search: '',
      headers: [
        { text: 'Name', value: 'parameter_name' },
        { text: 'Value or State', value: 'val_and_states' },
        { text: 'Units', value: 'units' },
        { text: 'Description', value: 'description' },
      ],
      targetName: '',
      commandName: '',
      ignoreRangeChecks: false,
      statesInHex: false,
      showIgnoredParams: false,
      cmdRaw: false,
      ignoredParams: [],
      rows: [],
      interfaces: [],
      selectedInterface: '',
      rawCmdFile: null,
      status: '',
      history: '',
      displaySendHazardous: false,
      displayErrorDialog: false,
      displaySendRaw: false,
      sendDisabled: false,
      api: null,
      viewDetails: false,
      contextMenuShown: false,
      parameterName: '',
      x: 0,
      y: 0,
      contextMenuOptions: [
        {
          title: 'Details',
          action: () => {
            this.contextMenuShown = false
            this.viewDetails = true
          },
        },
      ],
      menus: [
        // TODO: Implement send raw
        // {
        //   label: 'File',
        //   items: [
        //     {
        //       label: 'Send Raw',
        //       command: () => {
        //         this.setupRawCmd()
        //       }
        //     }
        //   ]
        // },
        {
          label: 'Mode',
          items: [
            {
              label: 'Ignore Range Checks',
              checkbox: true,
              command: () => {
                this.ignoreRangeChecks = !this.ignoreRangeChecks
              },
            },
            {
              label: 'Display State Values in Hex',
              checkbox: true,
              command: () => {
                this.statesInHex = !this.statesInHex
              },
            },
            {
              label: 'Show Ignored Parameters',
              checkbox: true,
              command: () => {
                this.showIgnoredParams = !this.showIgnoredParams
                // TODO: Maybe we don't need to do this if the data-table
                // can render the whole thing and we just display with v-if
                this.updateCmdParams()
              },
            },
            {
              label: 'Disable Parameter Conversions',
              checkbox: true,
              command: () => {
                this.cmdRaw = !this.cmdRaw
              },
            },
          ],
        },
      ],
    }
  },
  created() {
    this.api = new CosmosApi()
    // If we're passed in the route then manually call commandChanged to update
    if (this.$route.params.target) {
      this.commandChanged({
        targetName: this.$route.params.target,
        packetName: this.$route.params.packet,
      })
    }
  },
  methods: {
    getBackgroundColor() {
      return this.$vuetify.theme.parsedTheme.tertiary.darken2
    },
    historyEnter(event) {
      // Prevent the enter key from actually causing a newline
      event.preventDefault()
      const textarea = this.$refs.history.$refs.input
      let pos = textarea.selectionStart
      // Find the newline after the cursor position
      let nextNewline = textarea.value.indexOf('\n', pos)
      // Get everything up to the next newline and split on newlines
      const lines = textarea.value.substr(0, nextNewline).split('\n')
      let command = lines[lines.length - 1]
      // Blank commands can happen if typing return on a blank line
      if (command === '') {
        return
      }

      // Remove the cmd("") wrapper
      let firstQuote = command.indexOf('"')
      let lastQuote = command.lastIndexOf('"')
      command = command.substr(firstQuote + 1, lastQuote - firstQuote - 1)
      this.sendCmd(command)
    },

    showContextMenu(e, row) {
      e.preventDefault()
      this.parameterName = row.item.parameter_name
      this.contextMenuShown = false
      this.x = e.clientX
      this.y = e.clientY
      this.$nextTick(() => {
        this.contextMenuShown = true
      })
    },

    isFloat(str) {
      // Regex to identify a string as a floating point number
      if (/^\s*[-+]?\d*\.\d+\s*$/.test(str)) {
        return true
      }
      // Regex to identify a string as a floating point number in scientific notation.
      if (/^\s*[-+]?(\d+((\.\d+)?)|(\.\d+))[eE][-+]?\d+\s*$/.test(str)) {
        return true
      }
      return false
    },

    isInt(str) {
      // Regular expression to identify a String as an integer
      if (/^\s*[-+]?\d+\s*$/.test(str)) {
        return true
      }

      // # Regular expression to identify a String as an integer in hexadecimal format
      if (/^\s*0[xX][\dabcdefABCDEF]+\s*$/.test(str)) {
        return true
      }
      return false
    },

    isArray(str) {
      // Regular expression to identify a String as an Array
      if (/^\s*\[.*\]\s*$/.test(str)) {
        return true
      }
      return false
    },

    removeQuotes(str) {
      // Return the string with leading and trailing quotes removed
      if (str.length < 2) {
        return str
      }
      var firstChar = str.charAt(0)
      if (firstChar != '"' && firstChar != "'") {
        return str
      }
      var lastChar = str.charAt(str.length - 1)
      if (firstChar != lastChar) {
        return str
      }
      return str.slice(1, -1)
    },

    convertToValue(param) {
      if (typeof param.val_and_states.val != 'string') {
        return param.val_and_states.val
      }

      var str = param.val_and_states.val
      var quotes_removed = this.removeQuotes(str)
      if (str == quotes_removed) {
        var upcaseStr = str.toUpperCase()

        if (
          (param.type == 'STRING' || param.type == 'BLOCK') &&
          upcaseStr.startsWith('0X')
        ) {
          var hexStr = upcaseStr.slice(2)
          if (hexStr.length % 2 != 0) {
            hexStr = '0' + hexStr
          }
          var jstr = { json_class: 'String', raw: [] }
          for (var i = 0; i < hexStr.length; i += 2) {
            var nibble = hexStr.charAt(i) + hexStr.charAt(i + 1)
            jstr.raw.push(parseInt(nibble, 16))
          }
          return jstr
        } else {
          if (upcaseStr == 'INFINITY') {
            return Infinity
          } else if (upcaseStr == '-INFINITY') {
            return -Infinity
          } else if (upcaseStr == 'NAN') {
            return NaN
          } else if (this.isFloat(str)) {
            return parseFloat(str)
          } else if (this.isInt(str)) {
            return parseInt(str)
          } else if (this.isArray(str)) {
            return eval(str)
          } else {
            return str
          }
        }
      } else {
        return quotes_removed
      }
    },

    convertToString(value) {
      var i = 0
      var return_value = ''
      if (Object.prototype.toString.call(value).slice(8, -1) === 'Array') {
        var arrayLength = value.length
        return_value = '[ '
        for (i = 0; i < arrayLength; i++) {
          if (
            Object.prototype.toString.call(value[i]).slice(8, -1) === 'String'
          ) {
            return_value += '"' + value[i] + '"'
          } else {
            return_value += value[i]
          }
          if (i != arrayLength - 1) {
            return_value += ', '
          }
        }
        return_value += ' ]'
      } else if (
        Object.prototype.toString.call(value).slice(8, -1) === 'Object'
      ) {
        if (value.json_class == 'String' && value.raw) {
          // This is binary data, display in hex.
          return_value = '0x'
          for (i = 0; i < value.raw.length; i++) {
            var nibble = value.raw[i].toString(16).toUpperCase()
            if (nibble.length < 2) {
              nibble = '0' + nibble
            }
            return_value += nibble
          }
        } else if (value.json_class == 'Float' && value.raw) {
          return_value = value.raw
        } else {
          // TBD - are there other objects that we need to handle?
          return_value = String(value)
        }
      } else {
        return_value = String(value)
      }
      return return_value
    },

    commandChanged(event) {
      if (
        this.targetName !== event.targetName ||
        this.commandName !== event.packetName
      ) {
        this.targetName = event.targetName
        this.commandName = event.packetName
        // Only updateCmdParams if we're not already in the middle of an update
        if (this.sendDisabled === false) {
          this.updateCmdParams()
        }
        this.$router
          .replace({
            name: 'CommandSender',
            params: {
              target: this.targetName,
              packet: this.commandName,
            },
          })
          // catch the error in case we route to where we already are
          .catch((err) => {})
      }
    },

    updateCmdParams() {
      const reserved = [
        'PACKET_TIMESECONDS',
        'PACKET_TIMEFORMATTED',
        'RECEIVED_TIMESECONDS',
        'RECEIVED_TIMEFORMATTED',
        'RECEIVED_COUNT',
      ]
      this.sendDisabled = true
      this.ignoredParams = []
      this.rows = []
      this.api.get_target(this.targetName).then(
        (target) => {
          this.ignoredParams = target.ignored_parameters
          this.api.get_command(this.targetName, this.commandName).then(
            (command) => {
              command.items.forEach((parameter) => {
                if (reserved.includes(parameter.name)) return
                if (
                  !this.ignoredParams.includes(parameter.name) ||
                  this.showIgnoredParams
                ) {
                  let val = parameter.default
                  if (parameter.required) {
                    val = ''
                  }
                  if (parameter.format_string) {
                    val = sprintf(parameter.format_string, parameter.default)
                  }
                  this.rows.push({
                    parameter_name: parameter.name,
                    val_and_states: {
                      val: val,
                      states: parameter.states,
                      selected_state: null,
                      selected_state_label: '',
                      manual_value: null,
                    },
                    description: parameter.description,
                    units: parameter.units,
                    type: parameter.data_type,
                  })
                }
              })
              this.sendDisabled = false
              this.status = ''
            },
            (error) => {
              this.displayError('getting command parameters', error)
            }
          )
        },
        (error) => {
          this.displayError('getting ignored parameters', error)
        }
      )
    },

    statusChange(event) {
      this.status = event.status
    },

    createParamList() {
      let paramList = {}
      for (var i = 0; i < this.rows.length; i++) {
        paramList[this.rows[i].parameter_name] = this.convertToValue(
          this.rows[i]
        )
      }
      return paramList
    },

    buildCmd() {
      this.sendCmd(this.targetName, this.commandName, this.createParamList())
    },

    // Note targetName can also be the entire command to send, e.g. "INST ABORT" or
    // "INST COLLECT with TYPE 0, DURATION 1, OPCODE 171, TEMP 10" when being
    // sent from the history. In that case commandName and paramList are undefined
    // and the api calls handle that.
    sendCmd(targetName, commandName, paramList) {
      this.sendDisabled = true
      let hazardous = false
      let cmd = ''
      this.api.get_cmd_hazardous(targetName, commandName, paramList).then(
        (response) => {
          hazardous = response

          if (hazardous) {
            this.displaySendHazardous = true
          } else {
            let obs
            if (this.cmdRaw) {
              if (this.ignoreRangeChecks) {
                cmd = 'cmd_raw_no_range_check'
                obs = this.api.cmd_raw_no_range_check(
                  targetName,
                  commandName,
                  paramList
                )
              } else {
                cmd = 'cmd_raw'
                obs = this.api.cmd_raw(targetName, commandName, paramList)
              }
            } else {
              if (this.ignoreRangeChecks) {
                cmd = 'cmd_no_range_check'
                obs = this.api.cmd_no_range_check(
                  targetName,
                  commandName,
                  paramList
                )
              } else {
                cmd = 'cmd'
                obs = this.api.cmd(targetName, commandName, paramList)
              }
            }

            obs.then(
              (response) => {
                this.processCmdResponse(true, response)
              },
              (error) => {
                this.processCmdResponse(false, error)
              }
            )
          }
        },
        (error) => {
          this.processCmdResponse(false, error)
        }
      )
    },

    sendHazardousCmd() {
      this.displaySendHazardous = false
      var paramList = this.createParamList()

      let obs = ''
      let cmd = ''
      if (this.cmdRaw) {
        if (this.ignoreRangeChecks) {
          cmd = 'cmd_no_checks'
          obs = this.api.cmd_raw_no_checks(
            this.targetName,
            this.commandName,
            paramList
          )
        } else {
          cmd = 'cmd_no_hazardous_check'
          obs = this.api.cmd_raw_no_hazardous_check(
            this.targetName,
            this.commandName,
            paramList
          )
        }
      } else {
        if (this.ignoreRangeChecks) {
          cmd = 'cmd_no_checks'
          obs = this.api.cmd_no_checks(
            this.targetName,
            this.commandName,
            paramList
          )
        } else {
          cmd = 'cmd_no_hazardous_check'
          obs = this.api.cmd_no_hazardous_check(
            this.targetName,
            this.commandName,
            paramList
          )
        }
      }

      obs.then(
        (response) => {
          this.processCmdResponse(true, response)
        },
        (error) => {
          this.processCmdResponse(false, error)
        }
      )
    },

    cancelHazardousCmd() {
      this.displaySendHazardous = false
      this.status = 'Hazardous command not sent'
      this.sendDisabled = false
    },

    processCmdResponse(cmd_sent, response) {
      var msg = ''
      if (cmd_sent) {
        msg = 'cmd("' + response[0] + ' ' + response[1]
        var keys = Object.keys(response[2])
        if (keys.length > 0) {
          msg += ' with '
          for (var i = 0; i < keys.length; i++) {
            var key = keys[i]
            msg += key + ' ' + this.convertToString(response[2][key])
            if (i < keys.length - 1) {
              msg += ', '
            }
          }
        }
        msg += '")'
        if (!this.history.includes(msg)) {
          this.history += msg + '\n'
        }
        msg += ' sent.'
        // Add the number of commands sent to the status message
        if (this.status.includes(msg)) {
          let parts = this.status.split('sent.')
          if (parts[1].includes('(')) {
            let num = parseInt(parts[1].substr(2, parts[1].indexOf(')') - 2))
            msg = parts[0] + 'sent. (' + (num + 1) + ')'
          } else {
            msg += ' (2)'
          }
        }
        this.status = msg
      } else {
        var context = 'sending ' + this.targetName + ' ' + this.commandName
        this.displayError(context, response, true)
      }
      this.sendDisabled = false
    },

    displayError(context, error, showDialog = false) {
      this.status = 'Error ' + context + ' due to ' + error.name
      if (error.message && error.message != '') {
        this.status += ': '
        this.status += error.message
      }
      if (showDialog) {
        this.displayErrorDialog = true
      }
    },

    setupRawCmd() {
      this.api.get_interface_names().then(
        (response) => {
          var interfaces = []
          for (var i = 0; i < response.length; i++) {
            interfaces.push({ label: response[i], value: response[i] })
          }
          this.interfaces = interfaces
          this.selectedInterface = interfaces[0].value
          this.displaySendRaw = true
        },
        (error) => {
          this.displaySendRaw = false
          this.displayError('getting interface names', error, true)
        }
      )
    },

    selectRawCmdFile(event) {
      this.rawCmdFile = event.target.files[0]
    },

    onLoad(event) {
      var bufView = new Uint8Array(event.target.result)
      var jstr = { json_class: 'String', raw: [] }
      for (var i = 0; i < bufView.length; i++) {
        jstr.raw.push(bufView[i])
      }

      this.api.send_raw(this.selectedInterface, jstr).then(
        () => {
          this.displaySendRaw = false
          this.status =
            'Sent ' +
            bufView.length +
            ' bytes to interface ' +
            this.selectedInterface
        },
        (error) => {
          this.displaySendRaw = false
          this.displayError('sending raw data', error, true)
        }
      )
    },

    sendRawCmd() {
      var self = this
      var reader = new FileReader()
      reader.onload = function (e) {
        self.onLoad(e)
      }
      reader.onerror = function (e) {
        self.displaySendRaw = false
        var target = e.target
        self.displayError('sending raw data', target.error, true)
      }
      // TBD - use the other event handlers to implement a progress bar for the
      // file upload.  Handle abort as well?
      //reader.onloadstart = function(e) {}
      //reader.onprogress = function(e) {}
      //reader.onloadend = function(e) {}
      //reader.onabort = function(e) {}

      reader.readAsArrayBuffer(this.rawCmdFile)
    },

    cancelRawCmd() {
      this.displaySendRaw = false
      this.status = 'Raw command not sent'
    },
  },
}
</script>
