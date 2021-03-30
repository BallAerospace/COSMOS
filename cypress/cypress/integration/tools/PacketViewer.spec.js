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

describe('PacketViewer', () => {
  // Creates an alias to the ITEM value for later use
  function aliasItemValue(item) {
    // Grab the exact item name using RegExp
    cy.contains(new RegExp('^' + item + '$', 'g'))
      .parent() // Go up a level to get the enclosing element
      .children()
      .eq(2) // The third element is the Value (0 is index, 1 is label)
      // Perhaps there's an easier way but this creates an alias to the value
      // Which we can lookup later using cy.get(@itemValue)
      .within(() => {
        cy.get('input').invoke('val').as('itemValue')
      })
  }

  // Checks the ITEM value against a regular expression.
  // This is desireable as it continuously checks for the match
  // rather then setting an alias to the current value as above
  function matchItem(item, regex) {
    // Grab the exact item name using RegExp
    cy.contains(new RegExp('^' + item + '$', 'g'))
      .parent() // Go up a level to get the enclosing element
      .children()
      .eq(2) // The third element is the Value (0 is index, 1 is label)
      .within(() => {
        // Within the Value column
        cy.get('input') // Get the input
          .invoke('val') // and invoke 'val' which grabs the actual value
          .should('match', regex) // continously check the value to match
      })
  }
  //
  // Test the basic functionality of the application
  //
  it('displays INST HEALTH_STATUS & polls the api', () => {
    cy.visit('/tools/packetviewer/INST/HEALTH_STATUS')
    cy.hideNav()
    cy.contains('INST')
    cy.contains('HEALTH_STATUS')
    cy.contains('Health and status') // Description
    cy.server()
    cy.route('POST', '/api').as('api')
    cy.wait(2000) // Delay a little to ensure we're getting polled requests
    cy.wait('@api').should((xhr) => {
      expect(xhr.request.body.method).to.eql('get_tlm_packet')
      expect(xhr.status, 'successful POST').to.equal(200)
    })
  })
  it('selects a target and packet to display', () => {
    cy.visit('/tools/packetviewer')
    cy.hideNav()
    cy.selectTargetPacketItem('INST', 'IMAGE')
    cy.contains('INST')
    cy.contains('IMAGE')
    cy.contains('Packet with image data')
    cy.contains('BYTES')
  })
  it('gets details with right click', () => {
    cy.visit('/tools/packetviewer/INST/HEALTH_STATUS')
    cy.hideNav()
    cy.contains('HEALTH_STATUS')
    cy.contains(/^TEMP1$/)
      .parent() // Go up a level to get the enclosing element
      .children()
      .eq(2)
      .rightclick()
    cy.contains('Details').click()
    cy.get('.v-dialog:visible').contains('INST HEALTH_STATUS TEMP1')
  })
  it('stops posting to the api after closing', () => {
    // Override the fail handler to catch the expected fail
    Cypress.on('fail', (error) => {
      // Expect a No request error message once the API requests stop
      expect(error.message).to.include('No request ever occurred.')
      return false
    })
    cy.visit('/tools/packetviewer/INST/HEALTH_STATUS')
    cy.hideNav()
    cy.contains('INST')
    cy.contains('HEALTH_STATUS')
    cy.visit('/tools/cmdsender')
    cy.contains('Command Sender')
    cy.wait(1000) // Allow the initial Command Sender APIs to happen
    cy.server()
    cy.route('POST', '/api').as('api')
    cy.wait('@api', {
      requestTimeout: 1000,
    }).then((xhr) => {
      // If an xhr request is made this will fail the test which we want
      assert.isNull(xhr.response.body)
    })
  })

  //
  // Test the File menu
  //
  it('changes the polling rate', function () {
    cy.visit('/tools/packetviewer/INST/HEALTH_STATUS')
    cy.hideNav()
    cy.contains('TEMP1')
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('Options').click()
    cy.get('.v-dialog:visible').within(() => {
      cy.get('input').clear().type('5000')
    })
    cy.get('.v-dialog:visible').type('{esc}')
    cy.wait(1000)
    aliasItemValue('TEMP1')
    cy.get('@itemValue').then((value) => {
      cy.wait(3000)
      aliasItemValue('TEMP1')
      cy.get('@itemValue').should(($val) => {
        expect($val).to.eq(value)
      })
      cy.wait(3000)
      aliasItemValue('TEMP1')
      cy.get('@itemValue').then(($val) => {
        expect($val).to.not.eq(value)
      })
    })
  })

  //
  // Test the View menu
  //
  it('displays formatted items with units by default', function () {
    cy.visit('/tools/packetviewer/INST/HEALTH_STATUS')
    cy.hideNav()
    // Check for exactly 3 decimal points followed by units
    matchItem('TEMP1', /^-?\d+\.\d{3}\s\S$/)
  })
  it('displays formatted items with units', function () {
    cy.visit('/tools/packetviewer/INST/HEALTH_STATUS')
    cy.hideNav()
    cy.get('.v-toolbar').contains('View').click()
    cy.contains(/^Formatted Items with Units$/).click()
    // Check for exactly 3 decimal points followed by units
    matchItem('TEMP1', /^-?\d+\.\d{3}\s\S$/)
  })
  it('displays raw items', function () {
    cy.visit('/tools/packetviewer/INST/HEALTH_STATUS')
    cy.hideNav()
    cy.get('.v-toolbar').contains('View').click()
    cy.contains('Raw').click()
    // // Check for a raw number 1 to 99999
    matchItem('TEMP1', /^\d{1,5}$/)
  })
  it('displays converted items', function () {
    cy.visit('/tools/packetviewer/INST/HEALTH_STATUS')
    cy.hideNav()
    cy.get('.v-toolbar').contains('View').click()
    cy.contains('Converted').click()
    // Check for unformatted decimal points (4+)
    matchItem('TEMP1', /^-?\d+\.\d{4,}$/)
  })
  it('displays formatted items', function () {
    cy.visit('/tools/packetviewer/INST/HEALTH_STATUS')
    cy.hideNav()
    cy.get('.v-toolbar').contains('View').click()
    cy.contains(/^Formatted Items$/).click()
    // Check for exactly 3 decimal points
    matchItem('TEMP1', /^-?\d+\.\d{3}$/)
  })
  it('hides ignored items', function () {
    cy.visit('/tools/packetviewer/INST/HEALTH_STATUS')
    cy.hideNav()
    cy.contains('CCSDSVER').should('exist')
    cy.get('.v-toolbar').contains('View').click()
    cy.contains(/^Hide Ignored/).click()
    cy.contains('CCSDSVER').should('not.exist')
    cy.get('.v-toolbar').contains('View').click()
    cy.contains(/^Hide Ignored/).click()
    cy.contains('CCSDSVER').should('exist')
  })
  it('displays derived last', function () {
    cy.visit('/tools/packetviewer/INST/HEALTH_STATUS')
    cy.hideNav()
    cy.get('tbody>tr')
      .eq(0)
      .should('contain', '0')
      .and('contain', 'PACKET_TIMESECONDS')
    cy.get('.v-toolbar').contains('View').click()
    cy.contains(/^Display Derived/).click()
    cy.get('tbody>tr').eq(0).should('contain', '0').and('contain', 'CCSDSVER')
  })
})
