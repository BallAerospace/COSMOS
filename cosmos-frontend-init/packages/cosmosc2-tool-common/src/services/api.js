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

const request = async function (method, url, data = {}, params = {}) {
  try {
    await CosmosAuth.updateToken(30)
  } catch (error) {
    CosmosAuth.login()
  }
  params['token'] = localStorage.getItem('token')
  if (!params['scope']) {
    params['scope'] = 'DEFAULT'
  }
  return axios({
    method,
    url,
    data,
    params,
  })
}

export default {
  get: function (path, params) {
    return request('get', path, null, params)
  },

  put: function (path, data, params) {
    return request('put', path, data, params)
  },

  post: function (path, data, params) {
    return request('post', path, data, params)
  },

  delete: function (path, params) {
    return request('delete', path, null, params)
  },
}
