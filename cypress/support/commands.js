// 🦷 Dental System - Custom Cypress Commands

// Login command for authentication
Cypress.Commands.add('login', (email = Cypress.env('testUser').email, password = Cypress.env('testUser').password) => {
  cy.session([email, password], () => {
    cy.visit('/users/sign_in')
    cy.get('[data-testid="email-input"]').type(email)
    cy.get('[data-testid="password-input"]').type(password)
    cy.get('[data-testid="login-submit"]').click()
    cy.wait('@login')
    cy.url().should('not.include', '/users/sign_in')
    cy.get('[data-testid="user-menu"]').should('be.visible')
  })
})

// Create patient command
Cypress.Commands.add('createPatient', (patientData = Cypress.env('testPatient')) => {
  cy.get('[data-testid="new-patient-btn"]').click()
  cy.get('[data-testid="patient-name-input"]').type(patientData.name)
  cy.get('[data-testid="patient-phone-input"]').type(patientData.phone)
  cy.get('[data-testid="patient-email-input"]').type(patientData.email)
  cy.get('[data-testid="patient-submit"]').click()
  cy.wait('@createPatient')
  cy.get('[data-testid="success-message"]').should('contain', '患者を登録しました')
})

// Create appointment command
Cypress.Commands.add('createAppointment', (appointmentData) => {
  const defaultData = {
    patientName: 'テスト患者',
    date: '2025-07-05',
    time: '10:00',
    treatmentType: '定期検診'
  }
  const data = { ...defaultData, ...appointmentData }
  
  cy.get('[data-testid="new-appointment-btn"]').click()
  cy.get('[data-testid="patient-select"]').select(data.patientName)
  cy.get('[data-testid="appointment-date"]').type(data.date)
  cy.get('[data-testid="appointment-time"]').select(data.time)
  cy.get('[data-testid="treatment-type"]').select(data.treatmentType)
  cy.get('[data-testid="appointment-submit"]').click()
  cy.wait('@createAppointment')
  cy.get('[data-testid="success-message"]').should('contain', '予約を作成しました')
})

// Search functionality command
Cypress.Commands.add('searchFor', (query, type = 'all') => {
  cy.get('[data-testid="search-input"]').clear().type(query)
  if (type !== 'all') {
    cy.get('[data-testid="search-type"]').select(type)
  }
  cy.get('[data-testid="search-submit"]').click()
})

// Check table content command
Cypress.Commands.add('checkTableContains', (selector, content) => {
  cy.get(selector).should('be.visible')
  cy.get(selector).should('contain', content)
})

// Handle Rails CSRF tokens
Cypress.Commands.add('getCsrfToken', () => {
  return cy.get('meta[name="csrf-token"]').invoke('attr', 'content')
})

// API request with CSRF token
Cypress.Commands.add('apiRequest', (method, url, body = {}) => {
  return cy.getCsrfToken().then((token) => {
    return cy.request({
      method: method,
      url: url,
      body: body,
      headers: {
        'X-CSRF-Token': token,
        'Content-Type': 'application/json'
      }
    })
  })
})

// Wait for loading to complete
Cypress.Commands.add('waitForLoading', () => {
  cy.get('[data-testid="loading-spinner"]', { timeout: 10000 }).should('not.exist')
  cy.get('[data-testid="loading-indicator"]', { timeout: 10000 }).should('not.exist')
})

// Check responsive design
Cypress.Commands.add('checkResponsive', () => {
  // Test mobile view
  cy.viewport(375, 667)
  cy.get('[data-testid="mobile-menu"]').should('be.visible')
  
  // Test tablet view
  cy.viewport(768, 1024)
  cy.get('[data-testid="sidebar"]').should('be.visible')
  
  // Test desktop view
  cy.viewport(1280, 720)
  cy.get('[data-testid="main-nav"]').should('be.visible')
})

// Form validation helpers
Cypress.Commands.add('submitInvalidForm', (formSelector) => {
  cy.get(formSelector).within(() => {
    cy.get('[type="submit"]').click()
  })
  cy.get('[data-testid="validation-errors"]').should('be.visible')
})

// Calendar interaction
Cypress.Commands.add('selectDateFromCalendar', (date) => {
  cy.get('[data-testid="calendar-trigger"]').click()
  cy.get('[data-testid="calendar-popup"]').should('be.visible')
  cy.get(`[data-date="${date}"]`).click()
  cy.get('[data-testid="calendar-popup"]').should('not.exist')
})

// Data cleanup
Cypress.Commands.add('cleanupTestData', () => {
  // Clean up test appointments
  cy.apiRequest('DELETE', '/api/v1/test/cleanup/appointments')
  // Clean up test patients
  cy.apiRequest('DELETE', '/api/v1/test/cleanup/patients')
})