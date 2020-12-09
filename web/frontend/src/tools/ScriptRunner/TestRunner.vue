<template>
  <div>
    <v-container>
      <v-row no-gutters>
        <v-spacer />
        <v-col>
          <v-select
            label="Test Suite:"
            class="mr-2 mb-2"
            hide-details
            dense
            @change="suiteChanged"
            :items="suites"
            v-model="selectedSuite"
            data-test="select-suite"
          ></v-select>
        </v-col>
        <v-col cols="1">
          <v-btn
            color="primary"
            @click="$emit('start', { selectedSuite })"
            data-test="start-suite"
            >Start
          </v-btn>
        </v-col>
        <v-col cols="1">
          <v-btn
            color="primary"
            @click="$emit('setup', { selectedSuite })"
            data-test="setup-suite"
            :disabled="!setupSuiteEnabled"
            >Setup
          </v-btn>
        </v-col>
        <v-col cols="1">
          <v-btn
            color="primary"
            @click="$emit('teardown', { selectedSuite })"
            data-test="teardown-suite"
            :disabled="!setupSuiteEnabled"
            >Teardown
          </v-btn>
        </v-col>
      </v-row>
      <v-row no-gutters>
        <v-spacer />
        <v-col>
          <v-select
            label="Test Group:"
            class="mr-2 mb-2"
            hide-details
            dense
            @change="groupChanged"
            :items="groups"
            v-model="selectedGroup"
            data-test="select-group"
          ></v-select>
        </v-col>
        <v-col cols="1">
          <v-btn
            color="primary"
            @click="$emit('start', { selectedSuite, selectedGroup })"
            data-test="start-group"
            >Start
          </v-btn>
        </v-col>
        <v-col cols="1">
          <v-btn
            color="primary"
            @click="$emit('setup', { selectedSuite, selectedGroup })"
            data-test="setup-group"
            :disabled="!setupGroupEnabled"
            >Setup
          </v-btn>
        </v-col>
        <v-col cols="1">
          <v-btn
            color="primary"
            @click="$emit('teardown', { selectedSuite, selectedGroup })"
            data-test="teardown-group"
            :disabled="!teardownGroupEnabled"
            >Teardown
          </v-btn>
        </v-col>
      </v-row>
      <v-row no-gutters>
        <v-spacer />
        <v-col>
          <v-select
            label="Test Case:"
            class="mr-2 mb-2"
            hide-details
            dense
            @change="caseChanged"
            :items="cases"
            v-model="selectedCase"
            data-test="select-case"
          ></v-select>
        </v-col>
        <v-col cols="1">
          <v-btn
            color="primary"
            @click="
              $emit('start', { selectedSuite, selectedGroup, selectedCase })
            "
            data-test="start-case"
            >Start
          </v-btn>
        </v-col>
        <v-col cols="2"> </v-col>
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
      cases: [],
      selectedSuite: '',
      selectedGroup: '',
      selectedCase: '',
    }
  },
  computed: {
    setupSuiteEnabled() {
      if (this.selectedSuite && this.suiteMap[this.selectedSuite].setup) {
        return true
      } else {
        return false
      }
    },
    teardownSuiteEnabled() {
      if (this.selectedSuite && this.suiteMap[this.selectedSuite].teardown) {
        return true
      } else {
        return false
      }
    },
    setupGroupEnabled() {
      if (
        this.selectedSuite &&
        this.selectedGroup &&
        this.suiteMap[this.selectedSuite].tests[this.selectedGroup].setup
      ) {
        return true
      } else {
        return false
      }
    },
    teardownGroupEnabled() {
      if (
        this.selectedSuite &&
        this.selectedGroup &&
        this.suiteMap[this.selectedSuite].tests[this.selectedGroup].teardown
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
      this.selectedSuite = event
      this.selectedGroup = ''
      this.selectedCase = ''
      this.groups = Object.keys(this.suiteMap[event].tests)
      // Make the group default be the first group
      this.groupChanged(this.groups[0])
    },
    groupChanged(event) {
      this.selectedGroup = event
      this.selectedCase = ''
      this.cases = this.suiteMap[this.selectedSuite].tests[event].cases
      // Make the test case default be the first test
      this.caseChanged(this.cases[0])
    },
    caseChanged(event) {
      this.selectedCase = event
    },
  },
}
</script>

<style lang="scss" scoped></style>
