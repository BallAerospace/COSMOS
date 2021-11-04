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

const cmdRegex = /(^|\s)cmd\(['"`]/

const reservedParams = [
  'PACKET_TIMESECONDS',
  'PACKET_TIMEFORMATTED',
  'RECEIVED_TIMESECONDS',
  'RECEIVED_TIMEFORMATTED',
  'RECEIVED_COUNT',
]

export default class CommandCompleter {
  constructor() {
    this.api = new CosmosApi()
    this.commandAutocompleteData = [] // Data for the Ace autocomplete feature
    this.targetIgnoredParameters = {} // Data for the snippet builder code (this gets deleted once autocomplete data is built)

    this.api
      .get_target_list() // Get a list of all the targets
      .then((targetNames) => {
        // Get the details about each target
        return Promise.all(targetNames.map((name) => this.api.get_target(name)))
      })
      .then((targets) => {
        // Record each target's ignored parameters
        this.targetIgnoredParameters = Object.fromEntries(
          targets.map((target) => [target.name, target.ignored_parameters])
        )

        // Get each target's list of commands
        return Promise.all(
          targets.map((target) => this.api.get_all_commands(target.name))
        )
      })
      .then((commandsGroupedByTarget) => {
        // Map each command to Ace autocomplete data
        this.commandAutocompleteData = commandsGroupedByTarget.flatMap(
          (targetCommands) => targetCommands.map(this.toAutocompleteData)
        )
        delete this.targetIgnoredParameters // No longer needed; free up some space
      })
  }

  toAutocompleteData = (command) => ({
    caption: this.buildCommandCaption(command),
    snippet: this.buildCommandSnippet(command),
    meta: 'command',
  })

  buildCommandCaption = (command) =>
    `${command.target_name} ${command.packet_name}`

  buildCommandSnippet = (command) => {
    const caption = this.buildCommandCaption(command)
    const items = command.items.filter(
      (item) =>
        !reservedParams.includes(item.name) &&
        !this.targetIgnoredParameters[command.target_name].includes(item.name)
    )
    if (items.length) {
      const params = items
        .map((param, index) => {
          let value
          if (param.default === undefined) {
            value = 0
          } else if (
            typeof param.default === 'object' &&
            Array.isArray(param.default)
          ) {
            value = `[${param.default}]`
          } else {
            value = param.default
          }
          return `${param.name} \${${index + 1}:${value}}`
        })
        .join(', ')
      return `${caption} with ${params}`
    }
    return caption
  }

  getCompletions = function (editor, session, position, prefix, callback) {
    let matches = []
    const lineUntilCursor = session.doc.$lines[position.row]
      .slice(0, position.column)
      .trim()
    if (!!lineUntilCursor.match(cmdRegex)) {
      matches = this.commandAutocompleteData
    }

    callback(null, [
      ...matches,

      // Uncomment to also return the built-in autocomplete words (but I found they're not very good and just get in the way when using live autocomplete)
      // ...session.$mode.$highlightRules.$keywordList.map((word) => ({
      //   caption: word,
      //   value: word,
      //   meta: 'keyword',
      // })),
    ])
  }
}
