<template>
  <div>
    <app-nav app />
    <h1>COSMOS Administrator Console</h1>
    <p>
      To upload an entire COSMOS configuration zip the entire configuration
      folder. This is the folder which contains config/targets, outputs, etc. To
      upload a COSMOS target zip the target folder.
      <br />NOTE: This will OVERWRITE the existing target configuration.
    </p>
    <p>
      Windows: Install
      <a href="https://www.7-zip.org/">7-zip</a>, right click the folder and
      click 7-zip->Add to &lt;folder&gt;.zip
    </p>
    <p>Unix: zip -r config.zip &lt;folder&gt;</p>
    <v-row no-gutters align="center">
      <v-col cols="4">
        <v-file-input
          v-model="config"
          show-size
          label="Config Zip"
        ></v-file-input>
      </v-col>
      <v-col cols="1" class="pl-2">
        <v-btn color="primary" class="mr-4" @click="upload('config')">
          Upload
          <v-icon right dark>mdi-cloud-upload</v-icon>
        </v-btn>
      </v-col>
    </v-row>
    <v-row no-gutters align="center">
      <v-col cols="4">
        <v-file-input
          v-model="target"
          show-size
          label="Target Zip"
        ></v-file-input>
      </v-col>
      <v-col cols="1" class="pl-2">
        <v-btn color="primary" class="mr-4" @click="upload('target')">
          Upload
          <v-icon right dark>mdi-cloud-upload</v-icon>
        </v-btn>
      </v-col>
    </v-row>
    <v-alert :type="alertType" v-model="showAlert" dismissible>{{
      alert
    }}</v-alert>
  </div>
</template>

<script>
import AppNav from '@/AppNav'
import axios from 'axios'
export default {
  components: {
    AppNav
  },
  data() {
    return {
      config: null,
      target: null,
      alert: '',
      alertType: 'success',
      showAlert: false
    }
  },
  methods: {
    upload(type) {
      let formData = new FormData()
      let data = null
      if (type === 'config') {
        data = this.config
      } else {
        data = this.target
      }
      formData.append(type, data, data.name)
      axios
        .post('http://localhost:7777/admin/upload', formData)
        .then(response => {
          this.alert = 'Uploaded file'
          this.alertType = 'success'
          this.showAlert = true
        })
        .catch(error => {
          this.alert = error
          this.alertType = 'error'
          this.showAlert = true
        })
    }
  }
}
</script>
