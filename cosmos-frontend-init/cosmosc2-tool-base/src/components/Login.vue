<!--
# Copyright 2021 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder
-->

<template>
  <v-card>
    <v-card-title> Login </v-card-title>
    <v-card-subtitle>
      Enter the password to begin using COSMOS
    </v-card-subtitle>
    <v-card-text>
      <v-text-field
        v-model="password"
        type="password"
        :label="`${!isSet || reset ? 'New ' : ''}Password`"
      />
      <v-text-field
        v-if="reset"
        v-model="token"
        type="password"
        label="Reset Token"
      />
      <v-btn
        v-if="reset"
        @click="resetPassword"
        large
        color="warn"
        :disabled="!password || !token"
      >
        Reset
      </v-btn>
      <v-btn
        v-else-if="!isSet"
        @click="setPassword"
        large
        color="success"
        :disabled="!password"
      >
        Set
      </v-btn>
      <template v-else>
        <v-btn
          @click="verifyPassword"
          large
          color="success"
          :disabled="!password"
        >
          Login
        </v-btn>
        <!-- <v-btn text small @click="showReset"> Reset Password </v-btn> -->
      </template>
    </v-card-text>
    <v-alert :type="alertType" v-model="showAlert" dismissible>
      {{ alert }}
    </v-alert>
  </v-card>
</template>

<script>
import Api from '../../../packages/cosmosc2-tool-common/src/services/api'

export default {
  data() {
    return {
      isSet: true,
      password: '',
      token: '',
      reset: false,
      alert: '',
      alertType: 'success',
      showAlert: false,
    }
  },
  computed: {
    options: function () {
      return {
        noAuth: true,
        noScope: true, // lol
      }
    },
  },
  created: function () {
    Api.get('/cosmos-api/auth/token-exists', null, this.options).then(
      (response) => {
        this.isSet = !!response.data.result
      }
    )
  },
  methods: {
    showReset: function () {
      this.reset = true
    },
    login: function () {
      localStorage.token = this.password
      const redirect = new URLSearchParams(window.location.search).get(
        'redirect'
      )
      window.location = decodeURI(redirect)
    },
    verifyPassword: function () {
      this.showAlert = false
      Api.post(
        '/cosmos-api/auth/verify',
        {
          token: this.password,
        },
        null,
        this.options
      )
        .then((response) => {
          if (response.data.result) {
            this.login()
          } else {
            this.alert = 'Incorrect password'
            this.alertType = 'warning'
            this.showAlert = true
          }
        })
        .catch((error) => {
          this.alert = error
          this.alertType = 'error'
          this.showAlert = true
        })
    },
    setPassword: function () {
      this.showAlert = false
      Api.post(
        '/cosmos-api/auth/set',
        {
          token: this.password,
        },
        null,
        this.options
      )
        .then(this.login())
        .catch((error) => {
          this.alert = error
          this.alertType = 'error'
          this.showAlert = true
        })
    },
    resetPassword: function () {
      this.showAlert = false
      Api.post(
        '/cosmos-api/auth/reset',
        {
          token: this.password,
          recovery_token: this.token,
        },
        null,
        this.options
      )
        .then(this.login())
        .catch((error) => {
          this.alert = error
          this.alertType = 'error'
          this.showAlert = true
        })
    },
  },
}
</script>
