<template>
  <div>
    <v-row no-gutters align="center" style="padding-left: 10px">
      <v-col cols="3">
        <v-text-field v-model="name" label="Tool Name"></v-text-field>
      </v-col>
      <v-col cols="2">
        <v-text-field v-model="icon" label="Tool Icon"></v-text-field>
      </v-col>
      <v-col cols="3">
        <v-text-field v-model="url" label="Tool Url"></v-text-field>
      </v-col>
      <v-col cols="1" class="pl-2">
        <v-btn color="primary" class="mr-4" @click="add()">
          Add
          <v-icon right dark>mdi-plus</v-icon>
        </v-btn>
      </v-col>
    </v-row>
    <v-list data-test="toolList">
      <v-subheader class="mt-3">Tools</v-subheader>
      <v-list-item v-for="tool in tools" :key="tool">
        <v-list-item-content>
          <v-list-item-title v-text="tool"></v-list-item-title>
        </v-list-item-content>
        <v-list-item-icon>
          <v-tooltip bottom>
            <template v-slot:activator="{ on, attrs }">
              <v-icon @click="deleteTool(tool)" v-bind="attrs" v-on="on"
                >mdi-delete</v-icon
              >
            </template>
            <span>Delete Tool</span>
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
      name: null,
      icon: 'mdi-plus',
      url: null,
      tools: [],
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
        .get('http://localhost:7777/tools', {
          params: { scope: 'DEFAULT' },
        })
        .then((response) => {
          this.tools = response.data
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
    add() {
      if (this.name !== null && this.icon !== null && this.url !== null) {
        let data = { icon: this.icon, url: this.url }
        axios
          .post('http://localhost:7777/tools', {
            name: this.name,
            data: data,
            scope: 'DEFAULT',
          })
          .then((response) => {
            this.alert = 'Added tool ' + this.name
            this.alertType = 'success'
            this.showAlert = true
            setTimeout(() => {
              this.showAlert = false
            }, 5000)
            this.update()
          })
          .catch((error) => {
            this.alert = error
            this.alertType = 'error'
            this.showAlert = true
            setTimeout(() => {
              this.showAlert = false
            }, 5000)
          })
      } else {
        this.alert = 'Please Fill All Fields'
        this.alertType = 'warning'
        this.showAlert = true
        setTimeout(() => {
          this.showAlert = false
        }, 5000)
      }
    },
    deleteTool(name) {
      axios
        .delete('http://localhost:7777/tools/0', {
          params: { name: name, scope: 'DEFAULT' },
        })
        .then((response) => {
          this.alert = 'Removed tool ' + name
          this.alertType = 'success'
          this.showAlert = true
          setTimeout(() => {
            this.showAlert = false
          }, 5000)
          this.update()
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
  },
}
</script>
