<template>
  <div>
    <v-list data-test="targetList">
      <v-subheader class="mt-3">Targets</v-subheader>
      <v-list-item v-for="(target, i) in targets" :key="i">
        <v-list-item-content>
          <v-list-item-title v-text="target.name"></v-list-item-title>
        </v-list-item-content>
        <v-list-item-icon>
          <v-tooltip bottom>
            <template v-slot:activator="{ on, attrs }">
              <v-icon
                @click="deleteTarget(target.name)"
                v-bind="attrs"
                v-on="on"
                >mdi-delete</v-icon
              >
            </template>
            <span>Delete Target</span>
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
      targets: [],
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
        .get('http://localhost:7777/admin/targets', {
          params: { scope: 'DEFAULT' }
        })
        .then(response => {
          this.targets = response.data
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
    deleteTarget(name) {
      axios
        .delete('http://localhost:7777/admin/targets/0', {
          params: { name: name, scope: 'DEFAULT' }
        })
        .then(response => {
          this.alert = 'Removed target ' + name
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
