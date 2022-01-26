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
import { getKeywords, groupCmd, groupTlm } from './utilities'

const toMnemonicRegex = (word) => {
  // create regex to find the opening of a ruby method call
  const prefix = '(^|[{\\(\\s])' // Allowable characters before the method name: start of line or { or ( or a space
  const opening = '[\\s\\(][\'"]' // Opening sequence for a method call and a string argument: ( or a space, then ' or "
  return new RegExp(`${prefix}${word}${opening}`)
}

const mnemonicStringRegex = new RegExp('[\'"].+[\'"]')
const interpolatedStringRegex = new RegExp('#\\{.+\\}')

export default class MnemonicChecker {
  constructor() {
    this.api = new CosmosApi()

    this.targetList = [] // Used for the first level of validation to avoid a 500 being $notified
    this.api.get_target_list().then((response) => {
      this.targetList = response
    })

    this.cmdKeywordExpressions = []
    getKeywords('cmd').then((response) => {
      this.cmdKeywordExpressions = response.data.map(toMnemonicRegex)
    })

    this.tlmKeywordExpressions = []
    getKeywords('tlm').then((response) => {
      this.tlmKeywordExpressions = response.data.map(toMnemonicRegex)
    })
  }

  checkText = async function (text) {
    let linesToSkip = []
    const cmdLinesToCheck = []
    const tlmLinesToCheck = []
    text
      .split('\n')
      .reduce((linesToCheck, line, index) => {
        const match = line.match(mnemonicStringRegex)
        if (match) {
          const mnemonic = match[0].replace(/['"]/g, '')
          const interpolated = mnemonic.match(interpolatedStringRegex)
          const lineObj = {
            line,
            mnemonic,
            lineNumber: index + 1,
          }
          if (interpolated) {
            linesToSkip.push(lineObj)
          } else {
            linesToCheck.push(lineObj)
          }
        }
        return linesToCheck
      }, [])
      .forEach((lineObj) => {
        if (
          this.cmdKeywordExpressions.some((regex) => lineObj.line.match(regex))
        ) {
          cmdLinesToCheck.push(lineObj)
        } else if (
          this.tlmKeywordExpressions.some((regex) => lineObj.line.match(regex))
        ) {
          tlmLinesToCheck.push(lineObj)
        }
      })

    const cmdResult = await this._checkCmdLines(cmdLinesToCheck)
    const tlmResult = await this._checkTlmLines(tlmLinesToCheck)

    return {
      skipped: linesToSkip.sort((a, b) => a.lineNumber - b.lineNumber),
      problems: cmdResult
        .concat(tlmResult)
        .sort((a, b) => a.lineNumber - b.lineNumber),
    }
  }

  _checkCmdLines = async (linesToCheck) => {
    const problemLines = []
    const grouping = groupCmd(linesToCheck)
    for (const target in grouping) {
      if (!this.targetList.some((targetName) => targetName === target)) {
        for (const command in grouping[target]) {
          for (const lineObj of grouping[target][command]) {
            problemLines.push({
              ...lineObj,
              error: `Target "${target}" does not exist.`,
            })
          }
        }
        continue
      }
      const commands = await this.api.get_all_commands(target)
      for (const command in grouping[target]) {
        const commandInfo = commands.find(
          (info) => info.packet_name === command
        )
        if (commandInfo) {
          for (const lineObj of grouping[target][command]) {
            if (lineObj.params?.length) {
              for (const param of lineObj.params) {
                if (!commandInfo.items.some((item) => item.name === param)) {
                  problemLines.push({
                    ...lineObj,
                    error: `Command "${target} ${command}" parameter "${param}" does not exist.`,
                  })
                  break
                }
              }
            }
          }
        } else {
          for (const lineObj of grouping[target][command]) {
            problemLines.push({
              ...lineObj,
              error: `Command "${target} ${command}" does not exist.`,
            })
          }
        }
      }
    }
    return problemLines
  }

  _checkTlmLines = async (linesToCheck) => {
    const problemLines = []
    const grouping = groupTlm(linesToCheck)
    for (const target in grouping) {
      if (!this.targetList.some((targetName) => targetName === target)) {
        for (const packet in grouping[target]) {
          for (const item in grouping[target][packet]) {
            for (const lineObj of grouping[target][packet][item]) {
              problemLines.push({
                ...lineObj,
                error: `Target "${target}" does not exist.`,
              })
            }
          }
        }
        continue
      }
      const packets = await this.api.get_all_telemetry(target)
      for (const packet in grouping[target]) {
        const packetInfo = packets.find((info) => info.packet_name === packet)
        if (packetInfo) {
          for (const item in grouping[target][packet]) {
            if (!packetInfo.items.some((itemInfo) => itemInfo.name === item)) {
              for (const lineObj of grouping[target][packet][item]) {
                problemLines.push({
                  ...lineObj,
                  error: `Item "${target} ${packet} ${item}" does not exist.`,
                })
              }
            }
          }
        } else {
          for (const item in grouping[target][packet]) {
            for (const lineObj of grouping[target][packet][item]) {
              problemLines.push({
                ...lineObj,
                error: `Packet "${target} ${packet}" does not exist.`,
              })
            }
          }
        }
      }
    }
    return problemLines
  }
}
