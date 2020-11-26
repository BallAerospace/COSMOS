describe('ScriptRunner', () => {
  //
  // Test the basic functionality of the application
  //
  it('opens ready to type', () => {
    cy.visit('/script-runner')
    cy.hideNav()
    cy.focused().type('this is a test')
    cy.contains('this is a test')
  })
  it('runs unsaved scripts', () => {
    cy.visit('/script-runner')
    cy.hideNav()
    cy.focused().type('puts "Hello World"')
    cy.get('[data-test=start-go-button]').click()
    cy.get('[data-test=output-messages]', { timeout: 30000 }).contains(
      'Hello World'
    )
  })

  //
  // Test the File menu
  //
  it('clears the editor on File->New', () => {
    cy.visit('/script-runner')
    cy.hideNav()
    cy.focused().type('this is a test')
    cy.contains('this is a test')
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('New').click()
    cy.contains('this is a test').should('not.exist')
  })

  it('handles File Save, Save As, and Delete', () => {
    cy.visit('/script-runner')
    cy.hideNav()
    cy.focused().type('puts "File Save"')
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('Save File').click()
    cy.get('.v-dialog').within(() => {
      // New files automatically open File Save As
      cy.contains('File Save As')
      cy.get('[data-test=file-name]')
        .invoke('val')
        .should('include', 'Untitled')
      cy.get('[data-test=file-name]').clear().type('temp.rb')
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
      cy.get('[data-test=file-name]')
        .invoke('val')
        .should('include', 'INST/procedures')
      cy.get('[data-test=file-name]').type('/temp.rb')
      cy.contains('Ok').click()
    })
    cy.get('.v-dialog').should('not.be.visible')
    cy.get('[data-test=file-name]')
      .invoke('val')
      .should('eq', 'INST/procedures/temp.rb')

    // Type a little and verify it indicates the change
    cy.get('#editor').type('\n# comment1')
    cy.get('[data-test=file-name]')
      .invoke('val')
      .should('eq', 'INST/procedures/temp.rb *')
    // Save and verify it no longer indicates change
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('Save File').click()
    cy.get('[data-test=file-name]')
      .invoke('val')
      .should('eq', 'INST/procedures/temp.rb')

    // Type a little more and verify it indicates the change
    cy.get('#editor').type('\n# comment2')
    cy.get('[data-test=file-name]')
      .invoke('val')
      .should('eq', 'INST/procedures/temp.rb *')
    // File->Save As
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('Save As...').click()
    cy.get('.v-dialog').within(() => {
      // New files automatically open File Save As
      cy.contains('File Save As')
      cy.get('[data-test=file-name]')
        .invoke('val')
        .should('include', 'INST/procedures/temp.rb')
      cy.contains('Ok').click()
      cy.contains('Click OK to overwrite')
      cy.contains('Ok').click()
    })
    cy.get('.v-dialog').should('not.be.visible')
    cy.get('[data-test=file-name]')
      .invoke('val')
      .should('eq', 'INST/procedures/temp.rb')

    // Clear the editor
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('New File').click()
    cy.contains('puts "File Save"').should('not.exist')

    // Open the file
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('Open').click()
    cy.get('.v-dialog').within(() => {
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
    cy.readFile('cypress/downloads/INST_procedures_temp.rb').then(
      (contents) => {
        var lines = contents.split('\n')
        expect(lines[0]).to.contain('puts "File Save"')
        expect(lines[1]).to.contain('# comment1')
        expect(lines[2]).to.contain('# comment2')
      }
    )

    // Delete the file
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('Delete').click()
    cy.get('.v-dialog').within(() => {
      cy.contains('Ok').click()
    })
    cy.contains('puts "File Save"').should('not.exist')
  })

  it('downloads an unnamed file', () => {
    cy.visit('/script-runner')
    cy.hideNav()
    cy.focused().type('this is a test\nanother line')
    // Download the file
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('Download').click()
    cy.readFile('cypress/downloads/_Untitled_.txt').then((contents) => {
      var lines = contents.split('\n')
      expect(lines[0]).to.contain('this is a test')
      expect(lines[1]).to.contain('another line')
    })
  })

  //
  // Test the Script menu
  //
  it('runs Ruby Syntax check', () => {
    cy.visit('/script-runner')
    cy.hideNav()
    cy.focused().type('if')
    cy.get('.v-toolbar').contains('Script').click()
    cy.contains('Ruby Syntax Check').click()
    cy.get('.v-dialog').within(() => {
      // New files automatically open File Save As
      cy.contains('Syntax Check Failed')
      cy.contains('unexpected end-of-input')
    })
  })

  it('does nothing for call stack when not running', () => {
    cy.visit('/script-runner')
    cy.hideNav()
    cy.get('.v-toolbar').contains('Script').click()
    cy.contains('Show Call Stack').click()
    cy.get('@consoleError').should('not.be.called')
  })

  it('displays debug prompt', () => {
    cy.visit('/script-runner')
    cy.hideNav()
    cy.get('.v-toolbar').contains('Script').click()
    cy.contains('Toggle Debug').click()
    cy.get('[data-test=debug-text]').should('be.visible')
    cy.get('.v-toolbar').contains('Script').click()
    cy.contains('Toggle Debug').click()
    cy.get('[data-test=debug-text]').should('not.be.visible')
  })

  it('displays disconnect icon', () => {
    cy.visit('/script-runner')
    cy.hideNav()
    cy.get('.v-toolbar').contains('Script').click()
    cy.contains('Toggle Disconnect').click()
    cy.get('.v-icon.mdi-connection').should('be.visible')
    cy.get('.v-toolbar').contains('Script').click()
    cy.contains('Toggle Disconnect').click()
    cy.get('.v-icon.mdi-connection').should('not.be.visible')
  })
})
