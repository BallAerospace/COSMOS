<template>
  <div>
    <v-list data-test="routerList">
      <v-subheader class="mt-3">Routers</v-subheader>
      <v-list-item v-for="(router, i) in routers" :key="i">
        <v-list-item-content>
          <v-list-item-title v-text="router.name"></v-list-item-title>
        </v-list-item-content>
        <v-list-item-icon>
          <v-tooltip bottom>
            <template v-slot:activator="{ on, attrs }">
              <v-icon
                @click="deleteRouter(router.name)"
                v-bind="attrs"
                v-on="on"
                >mdi-delete</v-icon
              >
            </template>
            <span>Delete Router</span>
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
      routers: [],
      alert: '',
      alertType: 'success',
      showAlert: false
    }
  },
  mounted() {
    this.update()
  },
  methods: {
    update() {
      axios
        .get('http://localhost:7777/admin/routers', {
          params: { scope: 'DEFAULT' }
        })
        .then(response => {
          this.routers = response.data
        })
        .catch(error => {
          this.alert = error
          this.alertType = 'error'
          this.showAlert = true
          setTimeout(() => {
            this.showAlert = false
          }, 5000)
        })
    },
    add() {},
    deleteInterface(name) {
      axios
        .delete('http://localhost:7777/admin/routers/0', {
          params: { name: name, scope: 'DEFAULT' }
        })
        .then(response => {
          this.alert = 'Removed router ' + name
          this.alertType = 'success'
          this.showAlert = true
          setTimeout(() => {
            this.showAlert = false
          }, 5000)
          this.update()
        })
        .catch(error => {
          this.alert = error
          this.alertType = 'error'
          this.showAlert = true
          setTimeout(() => {
            this.showAlert = false
          }, 5000)
        })
    }
  }
}
</script>
