// 🦷 Dental System - Cypress E2E Test Support
// Import commands.js using ES2015 syntax:
import './commands'

// Alternatively you can use CommonJS syntax:
// require('./commands')

// Global test configuration
Cypress.on('uncaught:exception', (err, runnable) => {
  // Prevent Cypress from failing the test on uncaught exceptions
  // Return false here to prevent Cypress from failing the test
  if (err.message.includes('ResizeObserver loop limit exceeded')) {
    return false
  }
  if (err.message.includes('Non-Error promise rejection captured')) {
    return false
  }
  return true
})

// Custom assertions for dental system
chai.use(function (chai, utils) {
  // Custom assertion for appointment status
  chai.Assertion.addMethod('haveAppointmentStatus', function (expectedStatus) {
    const status = this._obj.getAttribute('data-status')
    this.assert(
      status === expectedStatus,
      `expected appointment to have status #{exp} but got #{act}`,
      `expected appointment not to have status #{exp}`,
      expectedStatus,
      status
    )
  })

  // Custom assertion for patient data
  chai.Assertion.addMethod('havePatientInfo', function (expectedInfo) {
    const element = this._obj
    const name = element.find('[data-patient-name]').text()
    const phone = element.find('[data-patient-phone]').text()
    
    this.assert(
      name.includes(expectedInfo.name),
      `expected patient name to contain #{exp} but got #{act}`,
      `expected patient name not to contain #{exp}`,
      expectedInfo.name,
      name
    )
  })
})

// Global before hook for test data setup
beforeEach(() => {
  // Intercept API calls for consistent testing
  cy.intercept('GET', '/api/v1/appointments*', { fixture: 'appointments.json' }).as('getAppointments')
  cy.intercept('GET', '/api/v1/patients*', { fixture: 'patients.json' }).as('getPatients')
  cy.intercept('POST', '/api/v1/appointments', { fixture: 'appointment_created.json' }).as('createAppointment')
  cy.intercept('POST', '/api/v1/patients', { fixture: 'patient_created.json' }).as('createPatient')
  cy.intercept('POST', '/api/v1/auth/login', { fixture: 'login_success.json' }).as('login')
})