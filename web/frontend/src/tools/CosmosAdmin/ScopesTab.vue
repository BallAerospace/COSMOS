<template>
  <div>
    <v-row no-gutters align="center">
      <v-col cols="4">
        <v-text-field v-model="scope" label="Scope Name"></v-text-field>
      </v-col>
      <v-col cols="1" class="pl-2">
        <v-btn color="primary" class="mr-4" @click="add()">
          Add
          <v-icon right dark>mdi-plus</v-icon>
        </v-btn>
      </v-col>
    </v-row>
    <v-list data-test="scopeList">
      <v-subheader class="mt-3">
        Scopes
      </v-subheader>
      <v-list-item v-for="(scope, i) in scopes" :key="i">
        <v-list-item-content>
          <v-list-item-title v-text="scope"></v-list-item-title>
        </v-list-item-content>
        <v-list-item-icon>
          <v-tooltip bottom>
            <template v-slot:activator="{ on, attrs }">
              <v-icon @click="deleteScope(scope)" v-bind="attrs" v-on="on"
                >mdi-delete</v-icon
              >
            </template>
            <span>Delete Scope</span>
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
      scope: null,
      scopes: [],
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
        .get('http://localhost:7777/admin/scopes')
        .then(response => {
          this.scopes = response.data
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
    add() {
      if (this.scope !== null) {
        axios
          .post('http://localhost:7777/admin/scopes', { scope: this.scope })
          .then(response => {
            this.alert = 'Added scope ' + this.scope
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
      } else {
        this.alert = 'Please Name the Scope'
        this.alertType = 'warning'
        this.showAlert = true
        setTimeout(() => {
          this.showAlert = false
        }, 5000)
      }
    },
    deleteScope(scope) {
      axios
        .delete('http://localhost:7777/admin/scopes/0', {
          params: { scope: scope }
        })
        .then(response => {
          this.alert = 'Removed scope ' + scope
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
