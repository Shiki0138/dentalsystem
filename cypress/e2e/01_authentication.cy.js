// 🦷 Dental System - Authentication E2E Tests

describe('Authentication Flow', () => {
  beforeEach(() => {
    cy.visit('/')
  })

  describe('User Login', () => {
    it('should redirect unauthenticated users to login page', () => {
      cy.url().should('include', '/users/sign_in')
      cy.get('[data-testid="login-form"]').should('be.visible')
      cy.get('h1').should('contain', 'ログイン')
    })

    it('should login with valid credentials', () => {
      cy.visit('/users/sign_in')
      cy.get('[data-testid="email-input"]').type(Cypress.env('testUser').email)
      cy.get('[data-testid="password-input"]').type(Cypress.env('testUser').password)
      cy.get('[data-testid="login-submit"]').click()
      
      cy.wait('@login')
      cy.url().should('not.include', '/users/sign_in')
      cy.get('[data-testid="dashboard"]').should('be.visible')
      cy.get('[data-testid="user-menu"]').should('contain', 'テスト歯科医師')
    })

    it('should show error with invalid credentials', () => {
      cy.visit('/users/sign_in')
      cy.get('[data-testid="email-input"]').type('wrong@email.com')
      cy.get('[data-testid="password-input"]').type('wrongpassword')
      cy.get('[data-testid="login-submit"]').click()
      
      cy.get('[data-testid="error-message"]').should('be.visible')
      cy.get('[data-testid="error-message"]').should('contain', 'メールアドレスまたはパスワードが正しくありません')
      cy.url().should('include', '/users/sign_in')
    })

    it('should validate email format', () => {
      cy.visit('/users/sign_in')
      cy.get('[data-testid="email-input"]').type('invalid-email')
      cy.get('[data-testid="password-input"]').type('password123')
      cy.get('[data-testid="login-submit"]').click()
      
      cy.get('[data-testid="validation-errors"]').should('be.visible')
      cy.get('[data-testid="email-input"]').should('have.class', 'is-invalid')
    })

    it('should require password field', () => {
      cy.visit('/users/sign_in')
      cy.get('[data-testid="email-input"]').type('test@dental.com')
      cy.get('[data-testid="login-submit"]').click()
      
      cy.get('[data-testid="password-input"]').should('have.class', 'is-invalid')
      cy.get('[data-testid="validation-errors"]').should('contain', 'パスワードを入力してください')
    })
  })

  describe('Two-Factor Authentication', () => {
    beforeEach(() => {
      // Mock 2FA enabled response
      cy.intercept('POST', '/api/v1/auth/login', {
        status: 'success',
        requires_2fa: true,
        message: '2段階認証コードを入力してください'
      }).as('loginWith2FA')
    })

    it('should prompt for 2FA code after valid login', () => {
      cy.visit('/users/sign_in')
      cy.get('[data-testid="email-input"]').type(Cypress.env('testUser').email)
      cy.get('[data-testid="password-input"]').type(Cypress.env('testUser').password)
      cy.get('[data-testid="login-submit"]').click()
      
      cy.wait('@loginWith2FA')
      cy.get('[data-testid="2fa-form"]').should('be.visible')
      cy.get('[data-testid="2fa-code-input"]').should('be.visible')
      cy.get('h2').should('contain', '2段階認証')
    })

    it('should accept valid 2FA code', () => {
      cy.intercept('POST', '/api/v1/auth/2fa/verify', {
        status: 'success',
        verified: true,
        redirect_to: '/dashboard'
      }).as('verify2FA')

      cy.visit('/users/sign_in')
      cy.get('[data-testid="email-input"]').type(Cypress.env('testUser').email)
      cy.get('[data-testid="password-input"]').type(Cypress.env('testUser').password)
      cy.get('[data-testid="login-submit"]').click()
      cy.wait('@loginWith2FA')
      
      cy.get('[data-testid="2fa-code-input"]').type('123456')
      cy.get('[data-testid="2fa-submit"]').click()
      
      cy.wait('@verify2FA')
      cy.url().should('include', '/dashboard')
    })

    it('should reject invalid 2FA code', () => {
      cy.intercept('POST', '/api/v1/auth/2fa/verify', {
        statusCode: 401,
        body: {
          status: 'error',
          message: '認証コードが正しくありません'
        }
      }).as('verify2FAFail')

      cy.visit('/users/sign_in')
      cy.get('[data-testid="email-input"]').type(Cypress.env('testUser').email)
      cy.get('[data-testid="password-input"]').type(Cypress.env('testUser').password)
      cy.get('[data-testid="login-submit"]').click()
      cy.wait('@loginWith2FA')
      
      cy.get('[data-testid="2fa-code-input"]').type('000000')
      cy.get('[data-testid="2fa-submit"]').click()
      
      cy.wait('@verify2FAFail')
      cy.get('[data-testid="error-message"]').should('contain', '認証コードが正しくありません')
      cy.get('[data-testid="2fa-form"]').should('be.visible')
    })

    it('should validate 2FA code format', () => {
      cy.visit('/users/sign_in')
      cy.get('[data-testid="email-input"]').type(Cypress.env('testUser').email)
      cy.get('[data-testid="password-input"]').type(Cypress.env('testUser').password)
      cy.get('[data-testid="login-submit"]').click()
      cy.wait('@loginWith2FA')
      
      // Test short code
      cy.get('[data-testid="2fa-code-input"]').type('123')
      cy.get('[data-testid="2fa-submit"]').click()
      cy.get('[data-testid="validation-errors"]').should('contain', '6桁の数字を入力してください')
      
      // Test non-numeric code
      cy.get('[data-testid="2fa-code-input"]').clear().type('abcdef')
      cy.get('[data-testid="2fa-submit"]').click()
      cy.get('[data-testid="validation-errors"]').should('contain', '6桁の数字を入力してください')
    })
  })

  describe('User Logout', () => {
    beforeEach(() => {
      cy.login()
      cy.visit('/dashboard')
    })

    it('should logout and redirect to login page', () => {
      cy.intercept('DELETE', '/api/v1/auth/logout', {
        status: 'success',
        message: 'ログアウトしました'
      }).as('logout')

      cy.get('[data-testid="user-menu"]').click()
      cy.get('[data-testid="logout-link"]').click()
      
      cy.wait('@logout')
      cy.url().should('include', '/users/sign_in')
      cy.get('[data-testid="success-message"]').should('contain', 'ログアウトしました')
    })

    it('should clear session data on logout', () => {
      cy.get('[data-testid="user-menu"]').click()
      cy.get('[data-testid="logout-link"]').click()
      
      // Try to access protected page
      cy.visit('/dashboard')
      cy.url().should('include', '/users/sign_in')
    })
  })

  describe('Session Management', () => {
    it('should redirect to login when session expires', () => {
      cy.login()
      cy.visit('/dashboard')
      
      // Mock session expiry
      cy.window().then((win) => {
        win.sessionStorage.clear()
        win.localStorage.removeItem('auth_token')
      })
      
      cy.reload()
      cy.url().should('include', '/users/sign_in')
    })

    it('should maintain session across page reloads', () => {
      cy.login()
      cy.visit('/dashboard')
      cy.get('[data-testid="dashboard"]').should('be.visible')
      
      cy.reload()
      cy.get('[data-testid="dashboard"]').should('be.visible')
      cy.url().should('not.include', '/users/sign_in')
    })
  })

  describe('Password Security', () => {
    it('should have password reset link', () => {
      cy.visit('/users/sign_in')
      cy.get('[data-testid="forgot-password-link"]').should('be.visible')
      cy.get('[data-testid="forgot-password-link"]').click()
      cy.url().should('include', '/users/password/new')
    })

    it('should mask password input', () => {
      cy.visit('/users/sign_in')
      cy.get('[data-testid="password-input"]').should('have.attr', 'type', 'password')
    })

    it('should have password visibility toggle', () => {
      cy.visit('/users/sign_in')
      cy.get('[data-testid="password-toggle"]').click()
      cy.get('[data-testid="password-input"]').should('have.attr', 'type', 'text')
      
      cy.get('[data-testid="password-toggle"]').click()
      cy.get('[data-testid="password-input"]').should('have.attr', 'type', 'password')
    })
  })
})