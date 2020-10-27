<template>
  <v-dialog v-model="show" width="550">
    <v-card>
      <v-card-title>File Open</v-card-title>
      <v-card-text>
        <v-container>
          <v-row no-gutters v-for="(file, key) in files" :key="key">
            <v-btn x-small color="primary" class="mr-2" @click="open(file)"
              >Open</v-btn
            >
            {{ file }}
          </v-row>
        </v-container>
      </v-card-text>
    </v-card>
  </v-dialog>
</template>

<script>
import axios from 'axios'

export default {
  props: {
    value: Boolean // value is the default prop when using v-model
  },
  data() {
    return {
      files: []
    }
  },
  computed: {
    show: {
      get() {
        return this.value
      },
      set(value) {
        this.$emit('input', value) // input is the default event when using v-model
      }
    }
  },
  created() {
    axios.get('http://localhost:3001/scripts').then(response => {
      this.files = []
      for (let file of response.data) {
        this.files.push(file)
      }
    })
  },
  methods: {
    open(file) {
      axios.get('http://localhost:3001/scripts/' + file).then(response => {
        this.show = false
        file = { name: file, contents: response.data }
        this.$emit('file', file)
      })
    }
  }
}
</script>
