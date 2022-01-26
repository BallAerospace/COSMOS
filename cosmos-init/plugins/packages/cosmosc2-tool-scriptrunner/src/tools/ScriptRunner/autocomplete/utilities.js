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

const getKeywords = (type) => {
  return Api.get(`/cosmos-api/autocomplete/keywords/${type}`)
}

const getAutocompleteData = (type) => {
  return Api.get(`/cosmos-api/autocomplete/data/${type}`)
}

// Group by target, then by either packet or command (whatever is the next token after the space)
const _groupByTargetX = (lines) => {
  const targetGroups = _groupBy(
    lines,
    (lineObj) => lineObj.mnemonic.split(' ')[0]
  )
  for (const target in targetGroups) {
    targetGroups[target] = _groupBy(
      targetGroups[target],
      (lineObj) => lineObj.mnemonic.split(' ')[1]
    )
  }
  return targetGroups
}

const groupTlm = (lines) => {
  const targetPacketGroups = _groupByTargetX(lines)

  // then group by packet
  for (const target in targetPacketGroups) {
    for (const packet in targetPacketGroups[target]) {
      targetPacketGroups[target][packet] = _groupBy(
        targetPacketGroups[target][packet],
        (lineObj) => lineObj.mnemonic.split(' ')[2]
      )
    }
  }
  return targetPacketGroups
}

const groupCmd = (lines) => {
  const targetCommandGroups = _groupByTargetX(lines)

  // then grab the params
  for (const target in targetCommandGroups) {
    for (const command in targetCommandGroups[target]) {
      targetCommandGroups[target][command] = targetCommandGroups[target][
        command
      ].map((lineObj) => {
        const params = lineObj.mnemonic
          .split(' with ')[1]
          ?.split(', ')
          .map((param) => param.split(' ')[0]) // Just the param name is all we care about
        return {
          ...lineObj,
          params,
        }
      })
    }
  }
  return targetCommandGroups
}

// This should probably go in some higher up util library thing place
const _groupBy = (array, lambda) => {
  return array.reduce((groups, item) => {
    const key = lambda(item)
    if (groups[key]) {
      groups[key].push(item)
    } else {
      groups[key] = [item]
    }
    return groups
  }, {})
}

export { getKeywords, getAutocompleteData, groupTlm, groupCmd }
