<template>
  <v-dialog persistent v-model="show" width="400">
    <v-card class="pa-3">
      <v-card-title class="headline">Ask</v-card-title>
      <v-card-text>
        {{ question }}
        <v-form
          v-model="valid"
          ref="form"
          @submit.prevent="$emit('submit', value)"
        >
          <v-text-field
            autofocus
            :type="password ? 'password' : 'text'"
            v-model="value"
            :rules="rules"
          ></v-text-field>
          <v-btn color="primary" :disabled="!valid" type="submit">Ok</v-btn>
          <v-btn
            class="ma-1"
            color="secondary"
            @click="$emit('submit', 'Cancel')"
            >Cancel</v-btn
          >
        </v-form>
      </v-card-text>
    </v-card>
  </v-dialog>
</template>

<script>
export default {
  props: {
    question: {
      type: String,
      required: true,
    },
    default: {
      type: String,
      default: null,
    },
    password: {
      type: Boolean,
      default: false,
    },
    answerRequired: {
      type: Boolean,
      default: true,
    },
  },
  data() {
    return {
      show: true,
      value: '',
      valid: false,
      rules: [(v) => !!v || 'Required'],
    }
  },
  created() {
    if (this.default) {
      this.valid = true
      this.value = this.default
    }
    if (this.answerRequired === false) {
      this.valid = true
      this.rules = [(v) => true]
    }
  },
}
</script>

<style scoped>
.theme--dark .v-card__title,
.theme--dark .v-card__subtitle {
  background-color: var(--v-secondary-darken3);
}
</style>
