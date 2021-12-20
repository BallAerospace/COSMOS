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
  beforeEach(() => {
    cy.visit('/tools/scriptrunner')
    cy.hideNav()
    cy.wait(1000)
  })

  afterEach(() => {
    //
  })

  //
  // Test the basic functionality of the application, not running scripts
  //
  it('opens ready to type', () => {
    cy.focused().type('this is a test')
    cy.contains('this is a test')
  })

  //
  // Test the File menu
  //
  it('clears the editor on File->New', () => {
    cy.get('#editor').type('this is a test')
    cy.contains('this is a test')
    cy.get('.v-toolbar').contains('File').click({ force: true })
    cy.contains('New').click({ force: true })
    cy.contains('this is a test').should('not.exist')
    cy.wait(1000)
  })

  it('handles File Save new file', () => {
    cy.get('#editor').type('puts "File Save"')
    cy.get('.v-toolbar').contains('File').click({ force: true })
    cy.contains('Save File').click({ force: true })
    cy.get('.v-dialog:visible').within(() => {
      // New files automatically open File Save As
      cy.contains('File Save As')
      cy.get('[data-test=filename]').invoke('val').should('include', 'Untitled')
      cy.get('[data-test=filename]').clear().type('temp.rb')
      cy.contains('temp.rb is not a valid filename')
      cy.contains('INST')
        .parentsUntil('button')
        .eq(0)
        .parent()
        .find('button')
        .click({ force: true })
      cy.contains('procedures').click({ force: true })
      // Verify the filename includes what we just clicked on
      cy.get('[data-test=filename]')
        .invoke('val')
        .should('include', 'INST/procedures')
      cy.get('[data-test=filename]').type('/temp.rb')
      cy.get('[data-test=file-open-save-submit-btn]').click({ force: true })
    })
    cy.get('.v-dialog:visible').should('not.exist')
    cy.get('[data-test=filename]')
      .invoke('val')
      .should('eq', 'INST/procedures/temp.rb')
    cy.wait(1000)
  })

  it('handles File Save overwrite', () => {
    cy.get('.v-toolbar').contains('File').click({ force: true })
    cy.contains('Open').click({ force: true })
    cy.get('.v-dialog:visible').within(() => {
      cy.contains('No file selected')
      cy.contains('INST').click({ force: true })
      cy.contains('procedures').click({ force: true })
      cy.contains('temp.rb').click({ force: true })
      cy.get('[data-test=file-open-save-submit-btn]').click({ force: true })
    })
    cy.get('body').then(($body) => {
      // Make sure the file isn't locked
      if ($body.text().includes('Editor is in read-only mode')) {
        cy.get('[data-test=unlock-button]').click({ force: true })
        cy.contains('Force Unlock').click({ force: true })
      }
    })
    // Type a little and verify it indicates the change
    cy.get('#editor').type('\n# comment1')
    cy.get('[data-test=filename]')
      .invoke('val')
      .should('eq', 'INST/procedures/temp.rb *')
    // Save and verify it no longer indicates change
    cy.get('.v-toolbar').contains('File').click({ force: true })
    cy.contains('Save File').click({ force: true })
    cy.get('[data-test=filename]')
      .invoke('val')
      .should('eq', 'INST/procedures/temp.rb')

    // Type a little more and verify it indicates the change
    cy.get('#editor').type('\n# comment2')
    cy.get('[data-test=filename]')
      .invoke('val')
      .should('eq', 'INST/procedures/temp.rb *')
    // File->Save As
    cy.get('.v-toolbar').contains('File').click({ force: true })
    cy.contains('Save As...').click({ force: true })
    cy.get('.v-dialog:visible').within(() => {
      // New files automatically open File Save As
      cy.contains('File Save As')
      cy.get('[data-test=filename]')
        .invoke('val')
        .should('include', 'INST/procedures/temp.rb')
      cy.contains('SAVE').click({ force: true })
    })
    cy.get('.dg-main-content').within(() => {
      cy.get('.dg-content').contains('Are you sure')
      cy.get('.dg-btn--ok').click({ force: true })
    })
    cy.wait(1000)
  })

  it('handles Save (ctrl + s)', () => {
    cy.get('.v-toolbar').contains('File').click({ force: true })
    cy.contains('Open').click({ force: true })
    cy.get('.v-dialog:visible').within(() => {
      cy.contains('No file selected')
      cy.contains('INST').click({ force: true })
      cy.contains('procedures').click({ force: true })
      cy.contains('temp.rb').click({ force: true })
      cy.get('[data-test=file-open-save-submit-btn]').click({ force: true })
    })
    cy.get('body').then(($body) => {
      // Make sure the file isn't locked
      if ($body.text().includes('Editor is in read-only mode')) {
        cy.get('[data-test=unlock-button]').click({ force: true })
        cy.contains('Force Unlock').click({ force: true })
      }
    })
    // Type a little and verify it indicates the change
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
    cy.get('.v-toolbar').contains('File').click({ force: true })
    cy.contains('New File').click({ force: true })
    cy.contains('puts "File Save"').should('not.exist')
    cy.wait(1000)
  })

  it('handles Download and Delete', () => {
    cy.get('.v-toolbar').contains('File').click({ force: true })
    cy.contains('Open').click({ force: true })
    cy.get('.v-dialog:visible').within(() => {
      cy.contains('No file selected')
      cy.contains('INST').click({ force: true })
      cy.contains('procedures').click({ force: true })
      cy.contains('temp.rb').click({ force: true })
      cy.get('[data-test=file-open-save-submit-btn]').click({ force: true })
    })
    // Verify we loaded the file contents
    cy.contains('puts "File Save"')
    // Download the file
    cy.get('.v-toolbar').contains('File').click({ force: true })
    cy.contains('Download').click({ force: true })
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
    cy.get('.v-toolbar').contains('File').click({ force: true })
    cy.contains('Delete').click({ force: true })
    cy.get('.dg-main-content').within(() => {
      cy.get('.dg-content').contains('Permanently delete file')
      cy.get('.dg-btn--ok').click({ force: true })
    })
    cy.contains('puts "File Save"').should('not.exist')
  })

  it('downloads an unnamed file', () => {
    cy.get('#editor').type('this is a test\nanother line')
    // Download the file
    cy.get('.v-toolbar').contains('File').click({ force: true })
    cy.contains('Download').click({ force: true })
    cy.readFile('cypress/downloads/_Untitled_.txt').then((contents) => {
      var lines = contents.split('\n')
      expect(lines[0]).to.contain('this is a test')
      expect(lines[1]).to.contain('another line')
    })
  })

  // Script menu tested by ScriptRunnerDebug
})
