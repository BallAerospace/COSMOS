<template>
  <div>
    <v-list data-test="microserviceList">
      <v-subheader class="mt-3">Microservices</v-subheader>
      <v-list-item v-for="microservice in microservices" :key="microservice">
        <v-list-item-content>
          <v-list-item-title v-text="microservice"></v-list-item-title>
        </v-list-item-content>
        <v-list-item-icon>
          <v-tooltip bottom>
            <template v-slot:activator="{ on, attrs }">
              <v-icon
                @click="deleteMicroservice(microservice)"
                v-bind="attrs"
                v-on="on"
                >mdi-delete</v-icon
              >
            </template>
            <span>Delete Microservice</span>
          </v-tooltip>
        </v-list-item-icon>
      </v-list-item>
    </v-list>
    <v-alert
      :type="alertType"
      v-model="showAlert"
      dismissible
      transition="scale-transition"
      >{{ alert }}</v-alert
    >
  </div>
</template>

<script>
import axios from 'axios'
export default {
  components: {},
  data() {
    return {
      microservices: [],
      alert: '',
      alertType: 'success',
      showAlert: false,
    }
  },
  mounted() {
    this.update()
  },
  methods: {
    update() {
      axios
        .get('http://localhost:7777/microservices', {
          params: { scope: 'DEFAULT' },
        })
        .then((response) => {
          this.microservices = response.data
        })
        .catch((error) => {
          this.alert = error
          this.alertType = 'error'
          this.showAlert = true
          setTimeout(() => {
            this.showAlert = false
          }, 5000)
        })
    },
    add() {},
    deleteMicroservice(name) {
      var self = this
      this.$dialog
        .confirm('Are you sure you want to remove: ' + name, {
          okText: 'Delete',
          cancelText: 'Cancel',
        })
        .then(function (dialog) {
          axios
            .delete('http://localhost:7777/microservices/' + name, {
              params: { scope: 'DEFAULT' },
            })
            .then((response) => {
              self.alert = 'Removed microservice ' + name
              self.alertType = 'success'
              self.showAlert = true
              setTimeout(() => {
                self.showAlert = false
              }, 5000)
              self.update()
            })
            .catch((error) => {
              self.alert = error
              self.alertType = 'error'
              self.showAlert = true
              setTimeout(() => {
                self.showAlert = false
              }, 5000)
            })
        })
    },
  },
}
</script>
