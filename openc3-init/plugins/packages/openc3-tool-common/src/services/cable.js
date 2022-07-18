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

import * as ActionCable from '@rails/actioncable'
//ActionCable.logger.enabled = true
ActionCable.ConnectionMonitor.staleThreshold = 60

export default class Cable {
  constructor(url = '/openc3-api/cable') {
    this._cable = ActionCable.createConsumer(url)
  }
  disconnect() {
    this._cable.disconnect()
  }
  createSubscription(channel, scope, callbacks = {}, additionalOptions = {}) {
    return OpenC3Auth.updateToken(OpenC3Auth.defaultMinValidity).then(() => {
      return this._cable.subscriptions.create(
        {
          channel,
          scope,
          token: localStorage.openc3Token,
          ...additionalOptions,
        },
        callbacks
      )
    })
  }
}
