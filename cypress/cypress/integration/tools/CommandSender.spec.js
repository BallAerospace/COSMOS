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

describe('CommandSender', () => {
  beforeEach(() => {
    cy.visit('/tools/cmdsender')
    cy.hideNav()
    // Make sure the Send button is enabled so we're ready
    cy.get('[data-test=select-send]', { timeout: 10000 }).should('not.have.class', 'v-btn--disabled')
  })

  // Helper function to select a parameter dropdown
  function selectValue(param, value) {
    cy.contains(param) // Find the parameter
      .parent() // Get the entire row
      .within(() => {
        // Within the row click the select to activate the drop down
        cy.get('[data-test=cmd-param-select]').click()
      })
    cy.get('.v-list-item__title').contains(value).click()
  }

  // Helper function to set parameter value
  function setValue(param, value) {
    cy.contains(param)
      .parent()
      .within(() => {
        cy.get('[data-test=cmd-param-value]')
          .clear()
          .type(value + '{enter}')
      })
    checkValue(param, value)
  }

  // Helper function to check parameter value
  function checkValue(param, value) {
    cy.contains(param)
      .parent()
      .within(() => {
        cy.get('[data-test=cmd-param-value]').invoke('val').should('eq', value)
      })
  }

  // Helper function to check command history
  function checkHistory(value) {
    cy.get('[data-test=sender-history]').invoke('val').should('include', value)
  }

  //
  // Test the basic functionality of the application
  //
  it('selects a target and packet', () => {
    cy.selectTargetPacketItem('INST', 'ABORT').wait(1000)
    cy.get('button').contains('Send').click().wait(1000)
    cy.contains('cmd("INST ABORT") sent')
  })

  it('displays INST COLLECT using the route', () => {
    cy.visit('/tools/cmdsender/INST/COLLECT').wait(1000)
    cy.contains('INST')
    cy.contains('COLLECT')
    cy.contains('Starts a collect')
    cy.contains('Parameters')
    cy.contains('DURATION')
  })

  it('displays state parameters with drop downs', () => {
    cy.selectTargetPacketItem('INST', 'COLLECT').wait(1000)
    selectValue('TYPE', 'SPECIAL')
    checkValue('TYPE', '1')
    selectValue('TYPE', 'NORMAL')
    checkValue('TYPE', '0')
  })

  it('supports manually entered state values', () => {
    cy.selectTargetPacketItem('INST', 'COLLECT').wait(1000)
    setValue('TYPE', '3')
    // Typing in the state value should automatically switch the state
    cy.contains('TYPE')
      .parent()
      .within(() => {
        cy.contains('MANUALLY ENTERED')
      })
    // Manually typing in an existing state value should change the state drop down
    setValue('TYPE', '0x0')
    cy.contains('TYPE').parent().contains('NORMAL')
    // Switch back to MANUALLY ENTERED
    selectValue('TYPE', 'MANUALLY ENTERED')
    setValue('TYPE', '3')
    cy.get('button').contains('Send').click().wait(1000)
    cy.contains(
      'Status: cmd("INST COLLECT with TYPE 3, DURATION 1, OPCODE 171, TEMP 0") sent'
    )
    checkHistory(
      'cmd("INST COLLECT with TYPE 3, DURATION 1, OPCODE 171, TEMP 0")'
    )
  })

  it('warns for hazardous commands', () => {
    cy.selectTargetPacketItem('INST', 'CLEAR').wait(1000)
    cy.contains('Clears counters')
    cy.get('button').contains('Send').click().wait(1000)
    cy.get('.v-dialog:visible').within(() => {
      cy.contains('No').click()
    })
    cy.contains('Hazardous command not sent')
    cy.get('button').contains('Send').click().wait(1000)
    cy.get('.v-dialog:visible').within(() => {
      cy.contains('Yes').click().wait(1000)
    })
    cy.contains('("INST CLEAR") sent')
    checkHistory('cmd("INST CLEAR")')
  })

  it('warns for required parameters', () => {
    cy.visit('/tools/cmdsender/INST/COLLECT')
    cy.hideNav()
    cy.wait(1000)
    cy.contains('Starts a collect')
    cy.get('button').contains('Send').click().wait(1000)
    cy.get('.v-dialog:visible').within(() => {
      // TODO: Make this clearer with 'TYPE is required'
      cy.contains('Error sending')
      cy.get('button').click()
    })
  })

  it('warns for hazardous parameters', () => {
    cy.visit('/tools/cmdsender/INST/COLLECT')
    cy.hideNav()
    cy.wait(1000)
    cy.contains('Starts a collect')
    selectValue('TYPE', 'SPECIAL')
    cy.get('button').contains('Send').click().wait(1000)
    cy.get('.v-dialog:visible').within(() => {
      cy.contains('No').click()
    })
    cy.contains('Hazardous command not sent')
    cy.get('button').contains('Send').click().wait(1000)
    cy.get('.v-dialog:visible').within(() => {
      cy.contains('Yes').click()
    })
    cy.contains(
      '("INST COLLECT with TYPE 1, DURATION 1, OPCODE 171, TEMP 0") sent'
    )
    checkHistory(
      'cmd("INST COLLECT with TYPE 1, DURATION 1, OPCODE 171, TEMP 0")'
    )
  })

  it('handles float values and scientific notation', () => {
    cy.visit('/tools/cmdsender/INST/FLTCMD')
    cy.hideNav()
    cy.wait(1000)
    cy.contains('float parameter')
    setValue('FLOAT32', '123.456')
    setValue('FLOAT64', '12e3')
    cy.get('button').contains('Send').click().wait(1000)
    cy.contains('("INST FLTCMD with FLOAT32 123.456, FLOAT64 12000") sent')
    checkHistory('cmd("INST FLTCMD with FLOAT32 123.456, FLOAT64 12000")')
  })

  it('handles array values', () => {
    cy.visit('/tools/cmdsender/INST/ARYCMD')
    cy.hideNav()
    cy.wait(1000)
    cy.contains('array parameter')
    setValue('ARRAY', '10')
    cy.get('button').contains('Send').click().wait(1000)
    cy.get('.v-dialog:visible').within(() => {
      cy.contains('must be an Array')
      cy.get('button').click()
    })
    setValue('ARRAY', '[1,2,3,4]')
    cy.get('button').contains('Send').click().wait(1000)
    cy.contains('cmd("INST ARYCMD with ARRAY [ 1, 2, 3, 4 ], CRC 0") sent')
    checkHistory('cmd("INST ARYCMD with ARRAY [ 1, 2, 3, 4 ], CRC 0")')
  })

  // TODO: This needs work
  it.skip('handles string values', () => {
    cy.visit('/tools/cmdsender/INST/ASCIICMD')
    cy.hideNav()
    cy.wait(1000)
    cy.contains('ASCII command')
    cy.get('button').contains('Send').click().wait(1000)
  })

  it('gets details with right click', () => {
    cy.visit('/tools/cmdsender/INST/COLLECT')
    cy.hideNav()
    cy.wait(1000)
    cy.contains('Starts a collect')
    cy.contains('TYPE').rightclick()
    cy.contains('Details').click()
    cy.get('.v-dialog:visible').contains('INST COLLECT TYPE')
    cy.get('.v-dialog:visible').type('{esc}')
  })

  it('executes commands from history', () => {
    cy.visit('/tools/cmdsender')
    cy.hideNav()
    cy.wait(1000)
    cy.selectTargetPacketItem('INST', 'CLEAR').wait(1000)
    cy.get('button').contains('Send').click().wait(1000)
    cy.wait(500)
    cy.get('.v-dialog:visible').within(() => {
      cy.contains('Yes').click()
    })
    cy.contains('cmd("INST CLEAR") sent.')
    checkHistory('cmd("INST CLEAR")')
    // Re-execute the command from the history
    cy.get('[data-test=sender-history]').click().type('{uparrow}{enter}')
    cy.wait(500)
    // Should still get the hazardous warning dialog
    cy.get('.v-dialog:visible').within(() => {
      cy.contains('Yes').click()
    })
    // Now history says it was sent twice (2)
    cy.contains('cmd("INST CLEAR") sent. (2)')
    cy.get('[data-test=sender-history]').click().type('{uparrow}{enter}')
    cy.wait(500)
    cy.get('.v-dialog:visible').within(() => {
      cy.contains('Yes').click()
    })
    // Now history says it was sent three times (3)
    cy.contains('cmd("INST CLEAR") sent. (3)')

    // Send a different command: INST SETPARAMS
    cy.selectTargetPacketItem('INST', 'SETPARAMS').wait(1000)
    cy.get('button').contains('Send').click({force: true}).wait(1000)
    cy.contains(
      'cmd("INST SETPARAMS with VALUE1 1, VALUE2 1, VALUE3 1, VALUE4 1, VALUE5 1") sent.'
    )
    // History should now contain both commands
    checkHistory('cmd("INST CLEAR")')
    checkHistory(
      'cmd("INST SETPARAMS with VALUE1 1, VALUE2 1, VALUE3 1, VALUE4 1, VALUE5 1")'
    )
    // Re-execute command
    cy.get('[data-test=sender-history]')
      .click()
      .type('{uparrow}{uparrow}{downarrow}{enter}')
    cy.contains(
      'cmd("INST SETPARAMS with VALUE1 1, VALUE2 1, VALUE3 1, VALUE4 1, VALUE5 1") sent. (2)'
    )
    // Edit the existing SETPARAMS command and then send
    cy.get('[data-test=sender-history]')
      .click()
      // This is somewhat fragile but not sure how else to edit
      .type('{leftarrow}{leftarrow}{leftarrow}{leftarrow}{del}5{enter}')
    cy.contains(
      'cmd("INST SETPARAMS with VALUE1 1, VALUE2 1, VALUE3 1, VALUE4 1, VALUE5 5") sent.'
    )
    // History should now contain CLEAR and both SETPARAMS commands
    checkHistory('cmd("INST CLEAR")')
    checkHistory(
      'cmd("INST SETPARAMS with VALUE1 1, VALUE2 1, VALUE3 1, VALUE4 1, VALUE5 1")'
    )
    checkHistory(
      'cmd("INST SETPARAMS with VALUE1 1, VALUE2 1, VALUE3 1, VALUE4 1, VALUE5 5")'
    )
  })

  //
  // Test the File menu
  //
  it.skip('sends raw data', () => {
    cy.visit('/tools/cmdsender')
    cy.hideNav()
    cy.wait(1000)
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('Send Raw').click().wait(1000)
  })

  //
  // Test the Mode menu
  //
  it('ignores range checks', () => {
    cy.visit('/tools/cmdsender/INST/COLLECT')
    cy.hideNav()
    cy.wait(1000)
    selectValue('TYPE', 'NORMAL') // Ensure TYPE is set since its required
    cy.get(
      ':nth-child(4) > :nth-child(2) > :nth-child(1) > .v-input > .v-input__control > .v-input__slot > .v-text-field__slot > [data-test=cmd-param-value]'
    )
      .clear()
      .type('100{enter}')
    cy.get('button').contains('Send').click().wait(1000)
    // Dialog should pop up with error
    cy.get('.v-dialog:visible').within(() => {
      cy.contains('not in valid range')
      cy.get('button').click() // Acknowledge the dialog
    })
    // TODO: This is due to the Network error popup ... not sure we want this
    cy.get('button').contains('Dismiss').click()

    // Status should also show error
    cy.contains('not in valid range')
    cy.get('.v-toolbar').contains('Mode').click()
    cy.contains('Ignore Range Checks').click()
    cy.get('button').contains('Send').click().wait(1000)
    cy.contains('TEMP 100") sent')
  })

  it('displays state values in hex', () => {
    cy.visit('/tools/cmdsender/INST/COLLECT')
    cy.hideNav()
    cy.wait(1000)
    selectValue('TYPE', 'NORMAL') // Ensure TYPE is set since its required
    checkValue('TYPE', '0')
    cy.get('.v-toolbar').contains('Mode').click().wait(1000)
    cy.contains('Display State').click()
    checkValue('TYPE', '0x0')
  })

  it('shows ignored parameters', () => {
    cy.visit('/tools/cmdsender/INST/ABORT')
    cy.hideNav()
    cy.wait(1000)
    cy.contains('Aborts a collect')
    // All the ABORT parameters are ignored so the table shouldn't appear
    cy.contains('Parameters').should('not.exist')
    cy.get('.v-toolbar').contains('Mode').click().wait(1000)
    cy.contains('Show Ignored').click().wait(1000)
    cy.contains('Parameters') // Now the parameters table is shown
    cy.contains('CCSDSVER') // CCSDSVER is one of the parameters
  })

  it('disable parameter conversions', () => {
    cy.visit('/tools/cmdsender/INST/COLLECT')
    cy.hideNav()
    cy.wait(1000)
    selectValue('TYPE', 'NORMAL') // Ensure TYPE is set since its required
    cy.get('.v-toolbar').contains('Mode').click().wait(1000)
    cy.contains('Disable Parameter').click().wait(1000)
    cy.get('button').contains('Send').click().wait(1000)
  })
})
