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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder
*/

// This tab of CmdTlmServer will be going away

describe('CmdTlmServer Status', () => {
  it('changes the limits set', () => {
    cy.visit('/tools/cmdtlmserver')
    cy.hideNav()
    cy.wait(1000)
    cy.get('.v-tab').contains('Status').click({ force: true })
    cy.wait(1000)
    cy.chooseVSelect('Limits Set', 'TVAC')
    // TODO: This message doesn't appear to be showing up
    // cy.get('[data-test=log-messages]').contains('Setting Limits Set: TVAC')
    cy.chooseVSelect('Limits Set', 'DEFAULT')
    // TODO: This message doesn't appear to be showing up
    // cy.get('[data-test=log-messages]').contains('Setting Limits Set: DEFAULT')
  })
})
