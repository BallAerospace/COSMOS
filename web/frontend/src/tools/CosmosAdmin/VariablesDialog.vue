<template>
  <v-dialog persistent v-model="show" width="400">
    <v-card class="pa-3">
      <v-card-title class="headline">Set Plugin Variables</v-card-title>
      <v-card-text>
        <v-form ref="form" @submit.prevent="$emit('submit', local_variables)">
          <div v-for="(value, name) in local_variables" :key="name">
            {{ name }}
            <v-text-field
              autofocus
              type="text"
              v-model="local_variables[name]"
            ></v-text-field>
          </div>
          <v-btn color="primary" type="submit">Ok</v-btn>
        </v-form>
      </v-card-text>
    </v-card>
  </v-dialog>
</template>

<script>
export default {
  props: {
    variables: {
      type: Object,
      required: true,
    },
    value: Boolean, // value is the default prop when using v-model
  },
  data() {
    return {
      local_variables: JSON.parse(JSON.stringify(this.variables)),
    }
  },
  computed: {
    show: {
      get() {
        return this.value
      },
      set(value) {
        this.$emit('input', value) // input is the default event when using v-model
      },
    },
  },
}
</script>

<style scoped>
.v-card,
.v-card__title {
  background-color: var(--v-secondary-darken3);
}
</style>
