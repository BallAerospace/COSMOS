<template>
  <v-dialog v-model="show" width="550">
    <v-card>
      <v-card-title>File Save As...</v-card-title>
      <v-card-text>
        <v-text-field
          hide-details
          label="File Name"
          v-model="afileName"
        ></v-text-field>
      </v-card-text>
      <v-card-actions>
        <v-btn color="primary" text @click="save()">Ok</v-btn>
        <v-spacer></v-spacer>
        <v-btn color="primary" text @click="show = false">Cancel</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<script>
export default {
  props: {
    fileName: String,
    value: Boolean // value is the default prop when using v-model
  },
  data() {
    return {
      files: [],
      afileName: ''
    }
  },
  mounted() {
    this.afileName = this.fileName
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
  methods: {
    save(file) {
      this.$emit('fileName', this.afileName)
      this.show = false
    }
  }
}
</script>
