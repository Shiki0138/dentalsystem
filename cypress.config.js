const { defineConfig } = require('cypress')

module.exports = defineConfig({
  e2e: {
    baseUrl: 'http://localhost:3000',
    supportFile: 'cypress/support/e2e.js',
    specPattern: 'cypress/e2e/**/*.cy.js',
    viewportWidth: 1280,
    viewportHeight: 720,
    video: true,
    screenshotOnRunFailure: true,
    defaultCommandTimeout: 10000,
    requestTimeout: 10000,
    responseTimeout: 10000,
    pageLoadTimeout: 30000,
    
    // Test isolation
    testIsolation: true,
    
    // Environment variables
    env: {
      apiUrl: 'http://localhost:3000/api/v1',
      testUser: {
        email: 'test@dental.com',
        password: 'TestPass123!'
      },
      testPatient: {
        name: 'テスト患者',
        phone: '090-1234-5678',
        email: 'test.patient@example.com'
      }
    },
    
    setupNodeEvents(on, config) {
      // implement node event listeners here
      on('task', {
        // Custom tasks for database seeding, etc.
        log(message) {
          console.log(message)
          return null
        }
      })
    },
  },
  
  component: {
    devServer: {
      framework: 'react',
      bundler: 'webpack',
    },
  },
})