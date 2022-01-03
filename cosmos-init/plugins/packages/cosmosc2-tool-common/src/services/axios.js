/*
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
*/

import axios from 'axios'
import Vue from 'vue'

const vueInstance = new Vue()

const axiosInstance = axios.create({
  baseURL: location.origin,
  timeout: 10000,
  params: {},
})

axiosInstance.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response.status === 401) {
      delete localStorage.cosmosToken
      CosmosAuth.login(location.href)
    } else {
      let body = `HTTP ${error.response.status} - `
      if (error.response?.data?.message) {
        body += `${error.response.data.message}`
      } else if (error.response?.data?.exception) {
        body += `${error.response.data.exception}`
      } else if (error.response?.data?.error?.message) {
        if (error.response.data.error.class) {
          body += `${error.response.data.error.class} `
        }
        body += `${error.response.data.error.message}`
      } else {
        body += `${error.response?.data}`
      }
      vueInstance.$notify.serious({
        title: 'Network error',
        body,
      })
    }
    throw error
  }
)

export default axiosInstance
