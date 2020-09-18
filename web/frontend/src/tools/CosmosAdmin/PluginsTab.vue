<template>
  <div>
    <v-row no-gutters align="center">
      <v-col cols="4">
        <v-file-input
          v-model="file"
          show-size
          label="Click to Select Plugin .gem File"
        ></v-file-input>
      </v-col>
      <v-col cols="1" class="pl-2">
        <v-btn color="primary" class="mr-4" @click="upload()">
          Upload
          <v-icon right dark>mdi-cloud-upload</v-icon>
        </v-btn>
      </v-col>
    </v-row>
    <v-list data-test="pluginList">
      <v-subheader class="mt-3">
        Plugins
      </v-subheader>
      <v-list-item v-for="(plugin, i) in plugins" :key="i">
        <v-list-item-content>
          <v-list-item-title v-text="plugin"></v-list-item-title>
        </v-list-item-content>
        <v-list-item-icon>
          <v-tooltip bottom>
            <template v-slot:activator="{ on, attrs }">
              <v-icon @click="deletePlugin(plugin)" v-bind="attrs" v-on="on"
                >mdi-delete</v-icon
              >
            </template>
            <span>Delete Item</span>
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
      file: null,
      plugins: [],
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
        .get('http://localhost:7777/admin/plugins')
        .then(response => {
          this.plugins = response.data
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
    upload() {
      if (this.file !== null) {
        let formData = new FormData()
        formData.append('plugin', this.file, this.file.name)
        axios
          .post('http://localhost:7777/admin/plugins', formData)
          .then(response => {
            this.alert = 'Uploaded file ' + this.file.name
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
        this.alert = 'Please Select A Plugin File'
        this.alertType = 'warning'
        this.showAlert = true
        setTimeout(() => {
          this.showAlert = false
        }, 5000)
      }
    },
    deletePlugin(plugin) {
      axios
        .delete('http://localhost:7777/admin/plugins/0', {
          params: { plugin: plugin }
        })
        .then(response => {
          this.alert = 'Removed plugin ' + plugin
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
