<template>
  <v-row justify="center">
    <v-dialog persistent v-model="show" width="400">
      <v-card>
        <v-card-title>{{ title }}</v-card-title>
        <v-card-text>
          {{ message }}
        </v-card-text>
        <v-divider></v-divider>
        <v-card-actions :class="layoutClass">
          <template v-if="layout === 'combo'">
            <v-select
              v-model="selectedItem"
              label="Select"
              class="ma-1"
              @change="selectOkDisabled = false"
              :items="computedButtons"
            ></v-select>
            <v-btn
              class="ma-1"
              color="secondary"
              :disabled="selectOkDisabled"
              @click="$emit('submit', selectedItem)"
              >Ok</v-btn
            >
            <v-btn
              class="ma-1"
              color="secondary"
              @click="$emit('submit', 'Cancel')"
              >Cancel</v-btn
            >
          </template>
          <v-btn
            v-else
            class="ma-1"
            v-for="(button, index) in computedButtons"
            :key="index"
            color="secondary"
            @click="$emit('submit', button.value)"
            >{{ button.text }}</v-btn
          >
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-row>
</template>

<script>
export default {
  props: {
    title: {
      type: String,
      default: 'Prompt Dialog'
    },
    message: {
      type: String,
      required: true
    },
    buttons: {
      type: Array,
      default: null
    },
    layout: {
      type: String,
      default: 'horizontal' // Also 'vertical' or 'combo' when means ComboBox
    }
  },
  data() {
    return {
      show: true,
      selectOkDisabled: true,
      selectedItem: null
    }
  },
  computed: {
    computedButtons() {
      return (
        this.buttons || [
          { text: 'Yes', value: true },
          { text: 'No', value: false }
        ]
      )
    },
    layoutClass() {
      let layout = 'd-flex align-start'
      if (this.layout === 'vertical') {
        return layout + ' flex-column'
      } else {
        return layout + ' flex-row'
      }
    }
  }
}
</script>

<style scoped>
.v-card,
.v-card__title {
  background-color: var(--v-secondary-darken3);
}
</style>
