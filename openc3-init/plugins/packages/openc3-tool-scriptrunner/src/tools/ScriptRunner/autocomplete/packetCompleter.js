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

import { getKeywords, getAutocompleteData } from './utilities'

const toMethodCallSyntaxRegex = (word) => {
  // create regex to find the opening of a ruby method call
  const prefix = '(^|[{\\(\\s])' // Allowable characters before the method name: start of line or { or ( or a space
  const opening = '[\\s\\(][\'"]' // Opening sequence for a method call and a string argument: ( or a space, then ' or "
  const params = '(\\S+\\s?){0,3}' // Only allow up to a few tokens after the keyword to avoid autocompleteception
  return new RegExp(`${prefix}${word}${opening}${params}$`) // ensure end of line because it's sliced to the current cursor position
}

export default class PacketCompleter {
  constructor(
    type,
    dataReadyCallback = () => {},
    expressionsReadyCallback = () => {}
  ) {
    this.keywordExpressions = [] // Keywords that trigger the autocomplete feature
    this.autocompleteData = [] // Data to populate the autocomplete list

    getKeywords(type).then((response) => {
      this.keywordExpressions = response.data.map(toMethodCallSyntaxRegex)
      expressionsReadyCallback()
    })
    getAutocompleteData(type).then((response) => {
      this.autocompleteData = response.data
      dataReadyCallback()
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
