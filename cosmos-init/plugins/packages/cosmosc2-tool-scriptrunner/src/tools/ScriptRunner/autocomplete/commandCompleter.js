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

import { CosmosApi } from '@cosmosc2/tool-common/src/services/cosmos-api'

const cmdRegex = /(^|\s)cmd\(/

const commandText = (command) => `${command.target_name} ${command.packet_name}`

const toAutocompleteData = (text) => ({
  caption: text,
  value: text,
  meta: 'command',
})

export default class CommandCompleter {
  constructor() {
    this.api = new CosmosApi()
    this.api
      .get_target_list()
      .then((targets) => {
        this.targetList = targets
        const promises = targets.map((target) =>
          this.api.get_all_commands(target)
        )
        return Promise.all(promises)
      })
      .then((responses) => {
        this.commandInfo = {} // Dictionary for looking up info about a typed command (e.g. its items)
        this.commandAutocompleteData = [] // Data for the Ace auto-complete feature

        responses.forEach((response) => {
          response.forEach((command) => {
            const text = commandText(command)
            this.commandInfo[text] = command
            this.commandAutocompleteData.push(toAutocompleteData(text))
          })
        })
      })
  }

  getCompletions = function (editor, session, position, prefix, callback) {
    let matches = []

    const lineUntilCursor = session.doc.$lines[position.row]
      .slice(0, position.column)
      .trim()

    if (!!lineUntilCursor.match(cmdRegex)) {
      matches = this.commandAutocompleteData // Don't need to filter it by what's already typed because Ace does that
    }

    callback(null, [
      ...matches,

      // Uncomment to also return the built-in autocomplete words
      // ...session.$mode.$highlightRules.$keywordList.map((word) => ({
      //   caption: word,
      //   value: word,
      //   meta: 'keyword',
      // })),
    ])
  }
}
