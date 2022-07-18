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

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved
*/

import { OpenC3Api } from '@openc3/tool-common/src/services/openc3-api'
import { getKeywords, groupBy } from './utilities'

const toKeywordRegex = (word) => {
  // create regex to find the opening of a ruby method call
  const prefix = '(^|[{\\(\\s])' // Allowable characters before the method name: start of line or { or ( or a space
  const call = '((\\s.+)|(\\(.+\\)))' // A method call and its arguments
  return new RegExp(`${prefix}${word}${call}`)
}
const interpolatedStringRegex = /#\{.+\}/
const alternateSyntaxRegex = /['"],\s?['"]/

export default class MnemonicChecker {
  constructor() {
    this.api = new OpenC3Api()

    this.targets = {}
    this.api.get_target_list().then((response) => {
      response.forEach((target) => {
        this.targets[target] = {
          cmd: null,
          tlm: null,
        }
      })
    })

    this.cmdKeywordExpressions = []
    getKeywords('cmd').then((response) => {
      this.cmdKeywordExpressions = response.data.map(toKeywordRegex)
    })

    this.tlmKeywordExpressions = []
    getKeywords('tlm').then((response) => {
      this.tlmKeywordExpressions = response.data.map(toKeywordRegex)
    })
  }

  checkText = async function (text) {
    const { linesToCheck, linesToSkip } = text.split('\n').reduce(
      (result, line, index) => {
        line = line.trim()
        if (line.match(/^#/)) {
          return result
        }
        const cmdMatch = this.cmdKeywordExpressions.reduce((found, regex) => {
          return found || line.match(regex)
        }, null)
        const tlmMatch = this.tlmKeywordExpressions.reduce((found, regex) => {
          return found || line.match(regex)
        }, null)
        if (!cmdMatch && !tlmMatch) {
          return result
        }

        const matchStr = (cmdMatch || tlmMatch)[0]
        const mnemonicMatch = matchStr
          .substring(matchStr.match(/[\(\s)]/).index + 1) // Trim off leading `cmd(` or whatever
          .replace(/\)\s*$/, '') // and the closing ) if it's there

        if (mnemonicMatch.match(interpolatedStringRegex)) {
          result.linesToSkip.push(index + 1)
          return result
        }

        const usingAlternateSyntax = !!mnemonicMatch.match(alternateSyntaxRegex)
        const mnemonicParts = mnemonicMatch.split(
          usingAlternateSyntax ? ',' : ' '
        )
        if (mnemonicParts.length < 2) {
          return result // TODO: is this right? Maybe put an error on lineObj?
        }

        const mnemonic = {
          target: mnemonicParts[0],
          packet: mnemonicParts[1],
        }
        if (tlmMatch) {
          mnemonic.item = mnemonicParts[2]
        } else {
          const mnemonicParams = mnemonicParts.slice(2)
          if (usingAlternateSyntax) {
            mnemonic.params = mnemonicParams.map(
              (param) => param.split('=>')[0]
            )
          } else {
            mnemonic.params = mnemonicParams.filter((token, index) => index % 2)
          }
        }

        // Clean up the quotes and whitespace from the parts of the mnemonic
        for (const property in mnemonic) {
          if (typeof mnemonic[property] === 'string') {
            mnemonic[property] = mnemonic[property].replace(/['"]/g, '').trim()
          } else {
            mnemonic[property] = mnemonic[property].map((item) =>
              item.replace(/['"]/g, '').trim()
            )
          }
        }

        result.linesToCheck.push({
          line,
          mnemonic,
          lineNumber: index + 1,
        })
        return result
      },
      { linesToCheck: [], linesToSkip: [] }
    )

    const problems = await this._checkLines(linesToCheck)
    return {
      skipped: linesToSkip.sort(),
      problems: problems.sort((a, b) => a.lineNumber - b.lineNumber),
    }
  }

  _checkLines = async (linesToCheck) => {
    const problemLines = []
    const targetGroups = groupBy(
      linesToCheck,
      (lineObj) => lineObj.mnemonic.target
    )
    for (const target in targetGroups) {
      if (!this.targets[target]) {
        for (const lineObj of targetGroups[target]) {
          problemLines.push({
            ...lineObj,
            error: `Target "${target}" does not exist.`,
          })
        }
        continue
      }
      const packetGroups = groupBy(
        targetGroups[target],
        (lineObj) => lineObj.mnemonic.packet
      )
      for (const packet in packetGroups) {
        for (const lineObj of packetGroups[packet]) {
          const cmdOrTlm = lineObj.mnemonic.item ? 'tlm' : 'cmd'
          if (!this.targets[target][cmdOrTlm]) {
            const method = lineObj.mnemonic.item
              ? 'get_all_telemetry'
              : 'get_all_commands'
            const response = await this.api[method](target)
            this.targets[target][cmdOrTlm] = response.reduce(
              (result, packetInfo) => {
                result[packetInfo.packet_name] = packetInfo.items.map(
                  (item) => item.name
                )
                return result
              },
              {}
            )
          }

          const items = this.targets[target][cmdOrTlm][packet]
          if (!items) {
            problemLines.push({
              ...lineObj,
              error: `${
                cmdOrTlm === 'tlm' ? 'Packet' : 'Command'
              } "${target} ${packet}" does not exist.`,
            })
            continue
          }
          if (lineObj.mnemonic.item) {
            if (!items.some((item) => item === lineObj.mnemonic.item)) {
              problemLines.push({
                ...lineObj,
                error: `Item "${target} ${packet} ${lineObj.mnemonic.item}" does not exist.`,
              })
              continue
            }
          } else {
            for (const param of lineObj.mnemonic.params) {
              if (!items.some((item) => item === param)) {
                problemLines.push({
                  ...lineObj,
                  error: `Command "${target} ${packet}" param "${param}" does not exist.`,
                })
                continue
              }
            }
          }
        }
      }
    }
    return problemLines
  }
}
