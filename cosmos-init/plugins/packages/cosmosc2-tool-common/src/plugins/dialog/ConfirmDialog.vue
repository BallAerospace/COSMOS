<template>
  <v-dialog v-model="show" width="600">
    <v-card>
      <v-system-bar>
        <v-spacer />
        <span> {{ params.title }} </span>
        <v-spacer />
      </v-system-bar>
      <v-card-text class="pa-3">
        <span v-if="params.html" v-html="params.text" class="pa-3"></span>
        <span v-else>{{ params.text }}</span>
      </v-card-text>
      <v-card-actions>
        <v-btn class="mx-2" color="primary" @click="ok"> {{ params.okText }} </v-btn>
        <v-spacer />
        <v-btn v-if="params.cancelText" class="mx-2" color="primary" @click="cancel"> {{ params.cancelText }} </v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<script>
import vuetify from '../vuetify.js'

export default {
  vuetify,
  data: function () {
    return {
      show: false,
      params: {
        title: 'Title',
        text: 'The text that is displayed',
        okText: 'Ok',
        cancelText: 'Cancel',
        html: false,
      },
      resolve: null,
      reject: null,
    }
  },
  methods: {
    dialog: function (params, resolve, reject) {
      this.params = params
      this.show = true
      this.resolve = resolve
      this.reject = reject
    },
    ok: function() {
      this.show = false
      this.resolve(true)
    },
    cancel: function() {
      this.show = false
      this.reject(true)
    }
  },
}
</script>

<style scoped>
</style>
