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
import { auth } from '@/auth'

export default {
  async get(path, params = {}) {
    try {
      await auth.updateToken(30)
    } catch (error) {
      auth.login()
    }
    params['token'] = localStorage.getItem('token')
    if (!params['scope']) {
      params['scope'] = 'DEFAULT'
    }
    return axios.get(path, { params })
  },

  async post(path, data, params = {}) {
    try {
      await auth.updateToken(30)
    } catch (error) {
      auth.login()
    }
    params['token'] = localStorage.getItem('token')
    if (!params['scope']) {
      params['scope'] = 'DEFAULT'
    }
    return axios.post(path, data, { params })
  },

  async delete(path, params = {}) {
    try {
      await auth.updateToken(30)
    } catch (error) {
      auth.login()
    }
    params['token'] = localStorage.getItem('token')
    if (!params['scope']) {
      params['scope'] = 'DEFAULT'
    }
    return axios.delete(path, { params })
  },
}
