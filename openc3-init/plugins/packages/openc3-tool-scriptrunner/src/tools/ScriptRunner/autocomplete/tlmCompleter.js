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

import PacketCompleter from './packetCompleter.js'

export default class TlmCompleter extends PacketCompleter {
  constructor() {
    super('tlm', () => {
      // The data returned by the API is usable as-is, but grouping it this way makes it easier
      // to search through all the packets first, and then for an item within that packet.
      this.groupedPacketData = this.autocompleteData.reduce((groups, item) => {
        const packetName = item.caption.match(/\S+\s\S+/)[0] // First two tokens, e.g. "INST ADCS" OF "INST ADCS POSX"
        const itemName = item.snippet.replace(`${packetName} `, '')
        const amendedItem = {
          caption: itemName,
          snippet: itemName,
          meta: 'item',
        }

        if (groups[packetName]) {
          groups[packetName].push(amendedItem)
        } else {
          groups[packetName] = [amendedItem]
        }
        return groups
      }, {})
      this.packets = Object.keys(this.groupedPacketData).map((packetName) => {
        return {
          caption: packetName,
          snippet: packetName,
          meta: 'packet',
        }
      })
    })
  }

  // Override the parent's getCompletions to take advantage of the grouping by packet done in the constructor
  getCompletions = function (editor, session, position, prefix, callback) {
    let matches = []
    const lineBeforeCursor = session.doc.$lines[position.row].slice(
      0,
      position.column
    )
    if (
      this.keywordExpressions.some((regex) => lineBeforeCursor.match(regex))
    ) {
      const foundPacket = Object.keys(this.groupedPacketData).find(
        (packetName) => lineBeforeCursor.includes(packetName)
      )
      if (foundPacket) {
        matches = this.groupedPacketData[foundPacket]
      } else {
        matches = this.packets
      }
    }

    callback(null, matches)
  }
}
