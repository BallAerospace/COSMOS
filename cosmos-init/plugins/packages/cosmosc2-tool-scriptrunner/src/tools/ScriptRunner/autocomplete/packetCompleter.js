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

import Api from '@cosmosc2/tool-common/src/services/api'

const toMethodCallSyntaxRegex = (word) =>
  new RegExp(`(^|[{\\(\\s])${word}[\\s\\(]['"]`)

export default class PacketCompleter {
  constructor(type) {
    this.keywordExpressions = [] // Keywords that trigger the autocomplete feature
    this.autocompleteData = [] // Data to populate the autocomplete list

    Api.get(`/cosmos-api/autocomplete/keywords/${type}`).then((response) => {
      this.keywordExpressions = response.data.map(toMethodCallSyntaxRegex)
    })
    Api.get(`/cosmos-api/autocomplete/data/${type}`).then((response) => {
      this.autocompleteData = response.data
    })
  }

  getCompletions = function (editor, session, position, prefix, callback) {
    let matches = []
    const lineBeforeCursor = session.doc.$lines[position.row].slice(
      0,
      position.column
    )
    if (
      this.keywordExpressions.some((regex) => lineBeforeCursor.match(regex))
    ) {
      matches = this.autocompleteData
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
