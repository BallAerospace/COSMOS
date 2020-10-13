<template>
  <div>
    <v-row no-gutters align="center">
      <v-col cols="4">
        <v-file-input
          v-model="file"
          show-size
          label="Click to Select .gem file to add to internal gem server"
        ></v-file-input>
      </v-col>
      <v-col cols="1" class="pl-2">
        <v-btn color="primary" class="mr-4" @click="upload()">
          Upload
          <v-icon right dark>mdi-cloud-upload</v-icon>
        </v-btn>
      </v-col>
    </v-row>
    <v-list data-test="gemList">
      <v-subheader class="mt-3">
        Gems
      </v-subheader>
      <v-list-item v-for="(gem, i) in gems" :key="i">
        <v-list-item-content>
          <v-list-item-title v-text="gem"></v-list-item-title>
        </v-list-item-content>
        <v-list-item-icon>
          <v-tooltip bottom>
            <template v-slot:activator="{ on, attrs }">
              <v-icon @click="deleteGem(gem)" v-bind="attrs" v-on="on"
                >mdi-delete</v-icon
              >
            </template>
            <span>Delete Gem</span>
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
      gems: [],
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
        .get('http://localhost:7777/admin/gems', {
          params: { scope: 'DEFAULT', token: localStorage.getItem('token') }
        })
        .then(response => {
          this.gems = response.data
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
        formData.append('gem', this.file, this.file.name)
        formData.append('scope', 'DEFAULT')
        formData.append('token', localStorage.getItem('token'))
        axios
          .post('http://localhost:7777/admin/gems', formData)
          .then(response => {
            this.alert = 'Uploaded gem ' + this.file.name
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
        this.alert = 'Please Select A Gem File'
        this.alertType = 'warning'
        this.showAlert = true
        setTimeout(() => {
          this.showAlert = false
        }, 5000)
      }
    },
    deleteGem(gem) {
      axios
        .delete('http://localhost:7777/admin/gems/0', {
          params: {
            gem: gem,
            scope: 'DEFAULT',
            token: localStorage.getItem('token')
          }
        })
        .then(response => {
          this.alert = 'Removed gem ' + gem
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
