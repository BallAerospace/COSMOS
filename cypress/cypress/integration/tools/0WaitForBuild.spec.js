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

describe('WaitForBuild', () => {
  it('waits for the services to deploy and connect', function () {
    cy.visit('/tools/cmdtlmserver')
    cy.hideNav()

    cy.get('[data-test=interfaces-table]')
      .contains('INST_INT', { timeout: 300000 })
      .parent()
      .children()
      .eq(2)
      .contains("CONNECTED")
    cy.get('[data-test=interfaces-table]')
      .contains('INST2_INT', { timeout: 60000 })
      .parent()
      .children()
      .eq(2)
      .contains("CONNECTED")
  })
})
