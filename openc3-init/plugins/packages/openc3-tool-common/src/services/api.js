/*
# Copyright 2022 Ball Aerospace & Technologies Corp.
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

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved
*/

import axios from './axios.js'

const request = async function (
  method,
  url,
  { data, params = {}, headers, noAuth = false, noScope = false } = {}
) {
  if (!noAuth) {
    try {
      await OpenC3Auth.updateToken(OpenC3Auth.defaultMinValidity)
    } catch (error) {
      OpenC3Auth.login()
    }
    headers['Authorization'] = localStorage.openc3Token
  }
  if (!noScope && !params['scope']) {
    params['scope'] = localStorage.scope
  }
  return axios({
    method,
    url,
    data,
    params,
    headers,
  })
}

const acceptOnlyDefaultHeaders = {
  Accept: 'application/json',
}

const fullDefaultHeaders = {
  ...acceptOnlyDefaultHeaders,
  'Content-Type': 'application/json',
}

export default {
  get: function (
    path,
    { params, headers = acceptOnlyDefaultHeaders, noScope, noAuth } = {}
  ) {
    return request('get', path, { params, headers, noScope, noAuth })
  },

  put: function (
    path,
    { data, params, headers = fullDefaultHeaders, noScope, noAuth } = {}
  ) {
    return request('put', path, { data, params, headers, noScope, noAuth })
  },

  post: function (
    path,
    { data, params, headers = fullDefaultHeaders, noScope, noAuth } = {}
  ) {
    return request('post', path, { data, params, headers, noScope, noAuth })
  },

  delete: function (
    path,
    { params, headers = acceptOnlyDefaultHeaders, noScope, noAuth } = {}
  ) {
    return request('delete', path, { params, headers, noScope, noAuth })
  },
}
