function getTodaysDate() {
  let today = new Date();
  let date = today.getFullYear() + '-' + (today.getMonth() + 1) + '-' + today.getDate();
  return date
}
// This returns the current hour then minutes is the min param
function getCurrentTime(min) {
  let today = new Date();
  let time = today.getHours() + ":" + min + ":00"
  // sometimes you want the current hour, sometimes the previous hour, manually enter military time
  let hour = "09"
  time = hour + ":" + min + ":00"
  return time
}
function getDownloadFilePath(username) {
  return "/Users/" + username + "/Downloads/2020-08-27_08_00_00.csv"
}

describe('TlmExtractor', () => {
  todaysDate = getTodaysDate()
  currentHour = getCurrentTime('00')
  currentHourPlus = getCurrentTime('15')
  //downloadFile = getDownloadFilePath('amuscare')

  it('Standard CSV output', function () {
    //cy.wait(5000)
    cy.visit('/telemetry-extractor')
    cy.hideNav()
    cy.get('[data-test=startdate]').type(todaysDate)
    cy.focused().click()
    cy.get('[data-test=enddate]').type(todaysDate)
    cy.focused().click()
    cy.get('[data-test=starttime]').type(currentHour)
    cy.focused().click()
    cy.get('[data-test=endtime]').type(currentHourPlus)
    cy.focused().click()
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
    cy.contains('Add Item').click()
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')
    cy.contains('Add Item').click()
    cy.contains('Process').click()
    cy.wait(5000)
    cy.contains('Download File').click()
    //cy.wait(5000)
    /*
    cy.parseCsv(downloadFile).then(
      jsonData => {
        console.log('taco')
        console.log(jsonData)
        expect(jsonData[0].data[0]).to.eqls(data);
      }
    )
      */
  })

  it('Tab delimited output', function () {
    cy.visit('/telemetry-extractor')
    cy.hideNav()
    cy.get('.v-toolbar')
      .contains('File')
      .click()
    cy.contains(/^Tab Delimited File$/).click()
    cy.get('[data-test=startdate]').type(todaysDate)
    cy.focused().click()
    cy.get('[data-test=enddate]').type(todaysDate)
    cy.focused().click()
    cy.get('[data-test=starttime]').type(currentHour)
    cy.focused().click()
    cy.get('[data-test=endtime]').type(currentHourPlus)
    cy.focused().click()
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
    cy.contains('Add Item').click()
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')
    cy.contains('Add Item').click()
    cy.contains('Process').click()
    cy.wait(5000)
    cy.contains('Download File').click()
  })
  it('Full Column Names in output', function () {
    cy.visit('/telemetry-extractor')
    cy.hideNav()
    cy.get('.v-toolbar')
      .contains('File')
      .click()
    cy.contains(/^Use Full Column Names$/).click()
    cy.get('[data-test=startdate]').type(todaysDate)
    cy.focused().click()
    cy.get('[data-test=enddate]').type(todaysDate)
    cy.focused().click()
    cy.get('[data-test=starttime]').type(currentHour)
    cy.focused().click()
    cy.get('[data-test=endtime]').type(currentHourPlus)
    cy.focused().click()
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
    cy.contains('Add Item').click()
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')
    cy.contains('Add Item').click()
    cy.contains('Process').click()
    cy.wait(5000)
    cy.contains('Download File').click()
  })
  it('Duplicate Item Triggers Warning', function () {
    cy.visit('/telemetry-extractor')
    cy.hideNav()
    cy.get('[data-test=startdate]').type(todaysDate)
    cy.focused().click()
    cy.get('[data-test=enddate]').type(todaysDate)
    cy.focused().click()
    cy.get('[data-test=starttime]').type(currentHour)
    cy.focused().click()
    cy.get('[data-test=endtime]').type(currentHourPlus)
    cy.focused().click()
    // Add the first item, INST/ADCS/CCSDSVER
    cy.contains('Add Item').click()
    cy.contains('Add Item').click()
    cy.contains('This item has already been added').should('be.visible')
  })
  it('Use Matlab Headers TSV output', function () {
    cy.visit('/telemetry-extractor')
    cy.hideNav()
    cy.get('.v-toolbar')
      .contains('File')
      .click()
    cy.contains(/^Tab Delimited File$/).click()
    cy.get('.v-toolbar')
      .contains('Mode')
      .click()
    cy.contains(/^Use Matlab Header$/).click()
    cy.get('[data-test=startdate]').type(todaysDate)
    cy.focused().click()
    cy.get('[data-test=enddate]').type(todaysDate)
    cy.focused().click()
    cy.get('[data-test=starttime]').type(currentHour)
    cy.focused().click()
    cy.get('[data-test=endtime]').type(currentHourPlus)
    cy.focused().click()
    cy.selectTargetPacketItem('INST', 'ADCS', 'Q1')
    cy.contains('Add Item').click()
    cy.selectTargetPacketItem('INST', 'ADCS', 'Q2')
    cy.contains('Add Item').click()
    cy.selectTargetPacketItem('INST', 'ADCS', 'PACKET_TIMEFORMATTED')
    cy.contains('Add Item').click()
    cy.contains('Process').click()
    cy.wait(5000)
    cy.contains('Download File').click()
  })
  /*
  it('Unique Only in the output csv', function () {
    cy.visit('/telemetry-extractor')
    cy.hideNav()
    cy.get('.v-toolbar')
      .contains('Mode')
      .click()
    cy.contains(/^Unique Only$/).click()
    cy.get('[data-test=startdate]').type(todaysDate)
    cy.focused().click()
    cy.get('[data-test=enddate]').type(todaysDate)
    cy.focused().click()
    cy.get('[data-test=starttime]').type(currentHour)
    cy.focused().click()
    cy.get('[data-test=endtime]').type(currentHourPlus)
    cy.focused().click()
    cy.selectTargetPacketItem('INST', 'ADCS', 'Q1')
    cy.contains('Add Item').click()
    cy.selectTargetPacketItem('INST', 'ADCS', 'Q2')
    cy.contains('Add Item').click()
    cy.selectTargetPacketItem('INST', 'ADCS', 'PACKET_TIMEFORMATTED')
    cy.contains('Add Item').click()
    cy.contains('Process').click()
    cy.wait(10000)
    cy.contains('Download File').click()
  })
*/
})
