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

describe('ScriptRunner', () => {
  //
  // Test the basic functionality of the application, not running scripts
  //
  it('opens ready to type', () => {
    cy.visit('/tools/scriptrunner')
    cy.focused().type('this is a test')
    cy.contains('this is a test')
  })

  //
  // Test the File menu
  //
  it('clears the editor on File->New', () => {
    cy.visit('/tools/scriptrunner')
    cy.get('#editor').type('this is a test')
    cy.contains('this is a test')
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('New').click()
    cy.contains('this is a test').should('not.exist')
  })

  it('handles File Save, Save As, and Delete', () => {
    cy.visit('/tools/scriptrunner')
    cy.get('#editor').type('puts "File Save"')
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('Save File').click()
    cy.get('.v-dialog:visible').within(() => {
      // New files automatically open File Save As
      cy.contains('File Save As')
      cy.get('[data-test=filename]').invoke('val').should('include', 'Untitled')
      cy.get('[data-test=filename]').clear().type('temp.rb')
      cy.contains('Ok').click()
      cy.contains('temp.rb is not a valid path / filename')
      cy.contains('INST')
        .parentsUntil('button')
        .eq(0)
        .parent()
        .find('button')
        .click()
      cy.contains('procedures').click()
      // Verify the filename includes what we just clicked on
      cy.get('[data-test=filename]')
        .invoke('val')
        .should('include', 'INST/procedures')
      cy.get('[data-test=filename]').type('/temp.rb')
      cy.contains('Ok').click()
    })
    cy.get('.v-dialog:visible').should('not.exist')
    cy.get('[data-test=filename]')
      .invoke('val')
      .should('eq', 'INST/procedures/temp.rb')

    // Type a little and verify it indicates the change
    cy.get('#editor').type('\n# comment1')
    cy.get('[data-test=filename]')
      .invoke('val')
      .should('eq', 'INST/procedures/temp.rb *')
    // Save and verify it no longer indicates change
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('Save File').click()
    cy.get('[data-test=filename]')
      .invoke('val')
      .should('eq', 'INST/procedures/temp.rb')

    // Type a little more and verify it indicates the change
    cy.get('#editor').type('\n# comment2')
    cy.get('[data-test=filename]')
      .invoke('val')
      .should('eq', 'INST/procedures/temp.rb *')
    // File->Save As
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('Save As...').click()
    cy.get('.v-dialog:visible').within(() => {
      // New files automatically open File Save As
      cy.contains('File Save As')
      cy.get('[data-test=filename]')
        .invoke('val')
        .should('include', 'INST/procedures/temp.rb')
      cy.contains('Ok').click()
      cy.contains('Click OK to overwrite')
      cy.contains('Ok').click()
    })
    cy.get('.v-dialog:visible').should('not.exist')
    cy.get('[data-test=filename]')
      .invoke('val')
      .should('eq', 'INST/procedures/temp.rb')

    // Type more and verify the Ctrl-S shortcut
    cy.get('#editor').type('\n# comment3')
    cy.get('[data-test=filename]')
      .invoke('val')
      .should('eq', 'INST/procedures/temp.rb *')
    cy.get('#editor').type('{ctrl}S')
    cy.get('[data-test=filename]')
      .invoke('val')
      .should('eq', 'INST/procedures/temp.rb')

    // Clear the editor
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('New File').click()
    cy.contains('puts "File Save"').should('not.exist')

    // Open the file
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('Open').click()
    cy.get('.v-dialog:visible').within(() => {
      cy.contains('Ok').click()
      cy.contains('Nothing selected')
      cy.get('[data-test=search]').type('temp')
      cy.contains('temp.rb')
      cy.get('[data-test=search]').clear()
      cy.contains('temp.rb').should('not.exist')
      cy.get('[data-test=search]').type('temp')
      cy.contains('temp.rb').click()
      cy.contains('Ok').click()
    })

    // Verify we loaded the file contents
    cy.contains('puts "File Save"')

    // Download the file
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('Download').click()
    // Can't test the contents because Chrome insists on popping up:
    // "This type of file can harm your computer. Do you want to keep <filename> anyway? Keep Discard"
    // after much googling there doesn't appear to be a way to disable it
    // cy.readFile('cypress/downloads/INST_procedures_temp.rb').then(
    //   (contents) => {
    //     var lines = contents.split('\n')
    //     expect(lines[0]).to.contain('puts "File Save"')
    //     expect(lines[1]).to.contain('# comment1')
    //     expect(lines[2]).to.contain('# comment2')
    //   }
    // )

    // Delete the file
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('Delete').click()
    cy.get('.v-dialog:visible').within(() => {
      cy.contains('Ok').click()
    })
    cy.contains('puts "File Save"').should('not.exist')
  })

  it('downloads an unnamed file', () => {
    cy.visit('/tools/scriptrunner')
    cy.get('#editor').type('this is a test\nanother line')
    // Download the file
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('Download').click()
    cy.readFile('cypress/downloads/_Untitled_.txt').then((contents) => {
      var lines = contents.split('\n')
      expect(lines[0]).to.contain('this is a test')
      expect(lines[1]).to.contain('another line')
    })
  })

  // Script menu tested by ScriptRunnerDebug
})
