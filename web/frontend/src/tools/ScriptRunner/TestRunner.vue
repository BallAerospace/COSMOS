<template>
  <div>
    <v-container id="tr-container">
      <v-row no-gutters align="center">
        <v-col cols="4">
          <v-row no-gutters>
            <v-col cols="6">
              <v-checkbox
                v-model="options"
                label="Pause on Error"
                value="pauseOnError"
                hide-details
              ></v-checkbox>
            </v-col>
            <v-col cols="6">
              <v-checkbox
                v-model="options"
                label="Manual"
                value="manual"
                hide-details
              ></v-checkbox>
            </v-col>
          </v-row>
        </v-col>
        <v-col cols="8">
          <v-row no-gutters justify="end">
            <v-col cols="5">
              <v-select
                label="Suite:"
                class="mr-2 mb-2"
                hide-details
                dense
                @change="suiteChanged"
                :items="suites"
                v-model="suite"
                data-test="select-suite"
              ></v-select>
            </v-col>
            <v-col cols="auto">
              <v-btn
                color="primary"
                class="mr-2"
                @click="$emit('button', { method: 'start', suite, options })"
                data-test="start-suite"
                >Start
              </v-btn>
              <v-btn
                color="primary"
                class="mr-2"
                @click="$emit('button', { method: 'setup', suite, options })"
                data-test="setup-suite"
                :disabled="!setupSuiteEnabled"
                >Setup
              </v-btn>
              <v-btn
                color="primary"
                @click="$emit('button', { method: 'teardown', suite, options })"
                data-test="teardown-suite"
                :disabled="!teardownSuiteEnabled"
                >Teardown
              </v-btn>
            </v-col>
          </v-row>
        </v-col>
      </v-row>
      <v-row no-gutters align="center">
        <v-col cols="4">
          <v-row no-gutters>
            <v-col cols="6">
              <v-checkbox
                v-model="options"
                label="Continue after Error"
                value="continueAfterError"
                hide-details
              ></v-checkbox>
            </v-col>
            <v-col cols="6">
              <v-checkbox
                v-model="options"
                label="Loop"
                value="loop"
                hide-details
              ></v-checkbox>
            </v-col>
          </v-row>
        </v-col>
        <v-col cols="8">
          <v-row no-gutters justify="end">
            <v-col cols="5">
              <v-select
                label="Group:"
                class="mr-2 mb-2"
                hide-details
                dense
                @change="groupChanged"
                :items="groups"
                v-model="group"
                data-test="select-group"
              ></v-select>
            </v-col>
            <v-col cols="auto">
              <v-btn
                color="primary"
                class="mr-2"
                @click="
                  $emit('button', { method: 'start', suite, group, options })
                "
                data-test="start-group"
                >Start
              </v-btn>
              <v-btn
                color="primary"
                class="mr-2"
                @click="
                  $emit('button', { method: 'setup', suite, group, options })
                "
                data-test="setup-group"
                :disabled="!setupGroupEnabled"
                >Setup
              </v-btn>
              <v-btn
                color="primary"
                @click="
                  $emit('button', { method: 'teardown', suite, group, options })
                "
                data-test="teardown-group"
                :disabled="!teardownGroupEnabled"
                >Teardown
              </v-btn>
            </v-col>
          </v-row>
        </v-col>
      </v-row>
      <v-row no-gutters align="center">
        <v-col cols="4">
          <v-row no-gutters>
            <v-col cols="6">
              <v-checkbox
                v-model="options"
                label="Abort after Error"
                value="abortAfterError"
                hide-details
              ></v-checkbox>
            </v-col>
            <v-col cols="6">
              <v-checkbox
                v-if="options.includes('loop')"
                v-model="options"
                label="Break Loop on Error"
                value="breakLoopOnError"
                hide-details
              ></v-checkbox>
            </v-col>
          </v-row>
        </v-col>
        <v-col cols="8">
          <v-row no-gutters justify="end">
            <v-col cols="5">
              <v-select
                label="Script:"
                class="mr-2 mb-2"
                hide-details
                dense
                @change="scriptChanged"
                :items="scripts"
                v-model="script"
                data-test="select-script"
              ></v-select>
            </v-col>
            <v-col cols="auto">
              <v-btn
                color="primary"
                @click="
                  $emit('button', {
                    method: 'start',
                    suite,
                    group,
                    script,
                    options,
                  })
                "
                data-test="start-script"
                >Start
              </v-btn>
              <!-- TODO: Don't like this hard coded spacer but not sure how else
              to push the Start button over to line up with the other Starts -->
              <div style="width: 300px" />
            </v-col>
          </v-row>
        </v-col>
      </v-row>
    </v-container>
  </div>
</template>

<script>
export default {
  props: {
    suiteMap: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      suites: [],
      groups: [],
      scripts: [],
      suite: '',
      group: '',
      script: '',
      options: [],
    }
  },
  computed: {
    setupSuiteEnabled() {
      if (this.suite && this.suiteMap[this.suite].setup) {
        return true
      } else {
        return false
      }
    },
    teardownSuiteEnabled() {
      if (this.suite && this.suiteMap[this.suite].teardown) {
        return true
      } else {
        return false
      }
    },
    setupGroupEnabled() {
      if (
        this.suite &&
        this.group &&
        this.suiteMap[this.suite].tests[this.group].setup
      ) {
        return true
      } else {
        return false
      }
    },
    teardownGroupEnabled() {
      if (
        this.suite &&
        this.group &&
        this.suiteMap[this.suite].tests[this.group].teardown
      ) {
        return true
      } else {
        return false
      }
    },
  },
  created() {
    this.suites = Object.keys(this.suiteMap)
  },
  methods: {
    suiteChanged(event) {
      this.suite = event
      this.group = ''
      this.script = ''
      this.groups = Object.keys(this.suiteMap[event].tests)
      // Make the group default be the first group
      this.groupChanged(this.groups[0])
    },
    groupChanged(event) {
      this.group = event
      this.script = ''
      this.scripts = this.suiteMap[this.suite].tests[event].cases
      // Make the script default be the first
      this.scriptChanged(this.scripts[0])
    },
    scriptChanged(event) {
      this.script = event
    },
  },
}
</script>

<style lang="scss" scoped>
#tr-container {
  padding-top: 0px;
  padding-bottom: 15px;
  padding-left: 0px;
  padding-right: 0px;
}
</style>
