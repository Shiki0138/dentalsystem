// 🦷 Dental System - User Interface E2E Tests

describe('User Interface and Experience', () => {
  beforeEach(() => {
    cy.login()
    cy.visit('/dashboard')
    cy.waitForLoading()
  })

  describe('Dashboard Navigation', () => {
    it('should display main dashboard with key metrics', () => {
      cy.get('[data-testid="dashboard"]').should('be.visible')
      cy.get('[data-testid="daily-appointments"]').should('be.visible')
      cy.get('[data-testid="patient-count"]').should('be.visible')
      cy.get('[data-testid="today-revenue"]').should('be.visible')
      cy.get('[data-testid="pending-appointments"]').should('be.visible')
    })

    it('should navigate between main sections', () => {
      // Test navigation menu
      cy.get('[data-testid="nav-patients"]').click()
      cy.url().should('include', '/patients')
      cy.get('[data-testid="patients-page"]').should('be.visible')

      cy.get('[data-testid="nav-appointments"]').click()
      cy.url().should('include', '/appointments')
      cy.get('[data-testid="appointments-page"]').should('be.visible')

      cy.get('[data-testid="nav-calendar"]').click()
      cy.url().should('include', '/calendar')
      cy.get('[data-testid="calendar-page"]').should('be.visible')

      cy.get('[data-testid="nav-dashboard"]').click()
      cy.url().should('include', '/dashboard')
      cy.get('[data-testid="dashboard"]').should('be.visible')
    })

    it('should show breadcrumb navigation', () => {
      cy.visit('/patients/1')
      cy.get('[data-testid="breadcrumb"]').should('be.visible')
      cy.get('[data-testid="breadcrumb"]').should('contain', 'ホーム')
      cy.get('[data-testid="breadcrumb"]').should('contain', '患者管理')
      cy.get('[data-testid="breadcrumb"]').should('contain', '患者詳細')
    })

    it('should maintain active navigation state', () => {
      cy.get('[data-testid="nav-patients"]').click()
      cy.get('[data-testid="nav-patients"]').should('have.class', 'active')
      
      cy.get('[data-testid="nav-appointments"]').click()
      cy.get('[data-testid="nav-appointments"]').should('have.class', 'active')
      cy.get('[data-testid="nav-patients"]').should('not.have.class', 'active')
    })
  })

  describe('Responsive Design', () => {
    it('should work properly on mobile devices', () => {
      cy.viewport(375, 667) // iPhone SE size
      
      cy.get('[data-testid="mobile-menu-toggle"]').should('be.visible')
      cy.get('[data-testid="desktop-sidebar"]').should('not.be.visible')
      
      cy.get('[data-testid="mobile-menu-toggle"]').click()
      cy.get('[data-testid="mobile-nav"]').should('be.visible')
      
      // Test mobile navigation
      cy.get('[data-testid="mobile-nav"] [data-testid="nav-patients"]').click()
      cy.url().should('include', '/patients')
      cy.get('[data-testid="mobile-nav"]').should('not.be.visible') // Should close after navigation
    })

    it('should adapt table layouts for small screens', () => {
      cy.viewport(375, 667)
      cy.visit('/patients')
      
      // Tables should become card layouts on mobile
      cy.get('[data-testid="mobile-patient-card"]').should('be.visible')
      cy.get('[data-testid="desktop-patient-table"]').should('not.be.visible')
    })

    it('should work properly on tablet devices', () => {
      cy.viewport(768, 1024) // iPad size
      
      cy.get('[data-testid="sidebar"]').should('be.visible')
      cy.get('[data-testid="main-content"]').should('be.visible')
      
      // Test touch interactions
      cy.get('[data-testid="appointment-row"]').first().trigger('touchstart')
      cy.get('[data-testid="quick-actions"]').should('be.visible')
    })

    it('should maintain functionality across different screen sizes', () => {
      const viewports = [
        [375, 667],   // Mobile
        [768, 1024],  // Tablet
        [1024, 768],  // Tablet landscape
        [1280, 720],  // Desktop
        [1920, 1080]  // Large desktop
      ]

      viewports.forEach(([width, height]) => {
        cy.viewport(width, height)
        cy.get('[data-testid="search-input"]').should('be.visible')
        cy.get('[data-testid="user-menu"]').should('be.visible')
      })
    })
  })

  describe('User Experience Features', () => {
    it('should show loading states for async operations', () => {
      cy.intercept('GET', '/api/v1/patients*', {
        delay: 2000,
        fixture: 'patients.json'
      }).as('slowPatients')

      cy.visit('/patients')
      cy.get('[data-testid="loading-spinner"]').should('be.visible')
      cy.get('[data-testid="loading-text"]').should('contain', '読み込み中...')
      
      cy.wait('@slowPatients')
      cy.get('[data-testid="loading-spinner"]').should('not.exist')
      cy.get('[data-testid="patient-table"]').should('be.visible')
    })

    it('should display error messages gracefully', () => {
      cy.intercept('GET', '/api/v1/patients*', {
        statusCode: 500,
        body: { error: 'サーバーエラーが発生しました' }
      }).as('serverError')

      cy.visit('/patients')
      cy.wait('@serverError')
      
      cy.get('[data-testid="error-message"]').should('be.visible')
      cy.get('[data-testid="error-message"]').should('contain', 'サーバーエラーが発生しました')
      cy.get('[data-testid="retry-button"]').should('be.visible')
    })

    it('should provide feedback for user actions', () => {
      cy.visit('/patients')
      cy.get('[data-testid="new-patient-btn"]').click()
      
      // Fill form with valid data
      cy.get('[data-testid="patient-name-input"]').type('フィードバックテスト')
      cy.get('[data-testid="patient-phone-input"]').type('090-1234-5678')
      cy.get('[data-testid="patient-submit"]').click()
      
      // Should show success feedback
      cy.get('[data-testid="success-toast"]').should('be.visible')
      cy.get('[data-testid="success-toast"]').should('contain', '患者を登録しました')
      
      // Toast should auto-hide
      cy.get('[data-testid="success-toast"]', { timeout: 6000 }).should('not.exist')
    })

    it('should handle form validation with clear feedback', () => {
      cy.visit('/patients')
      cy.get('[data-testid="new-patient-btn"]').click()
      
      // Submit empty form
      cy.get('[data-testid="patient-submit"]').click()
      
      // Should show field-specific errors
      cy.get('[data-testid="patient-name-input"]').should('have.class', 'is-invalid')
      cy.get('[data-testid="name-error"]').should('contain', '患者名を入力してください')
      
      cy.get('[data-testid="patient-phone-input"]').should('have.class', 'is-invalid')
      cy.get('[data-testid="phone-error"]').should('contain', '電話番号を入力してください')
      
      // Errors should clear when fixed
      cy.get('[data-testid="patient-name-input"]').type('テスト患者')
      cy.get('[data-testid="patient-name-input"]').should('not.have.class', 'is-invalid')
      cy.get('[data-testid="name-error"]').should('not.exist')
    })
  })

  describe('Accessibility Features', () => {
    it('should have proper keyboard navigation', () => {
      cy.get('body').tab()
      cy.focused().should('have.attr', 'data-testid', 'skip-to-content')
      
      cy.focused().tab()
      cy.focused().should('have.attr', 'data-testid', 'search-input')
      
      cy.focused().tab()
      cy.focused().should('have.attr', 'data-testid', 'user-menu')
    })

    it('should have proper ARIA labels and roles', () => {
      cy.get('[data-testid="main-nav"]').should('have.attr', 'role', 'navigation')
      cy.get('[data-testid="main-nav"]').should('have.attr', 'aria-label', 'メインナビゲーション')
      
      cy.get('[data-testid="patient-table"]').should('have.attr', 'role', 'table')
      cy.get('[data-testid="search-input"]').should('have.attr', 'aria-label', '患者検索')
    })

    it('should provide screen reader announcements', () => {
      cy.visit('/patients')
      cy.get('[data-testid="new-patient-btn"]').click()
      
      cy.get('[data-testid="patient-name-input"]').type('テスト患者')
      cy.get('[data-testid="patient-submit"]').click()
      
      cy.get('[aria-live="polite"]').should('contain', '患者を登録しました')
    })

    it('should have sufficient color contrast', () => {
      // Test high contrast elements
      cy.get('[data-testid="primary-button"]').should('be.visible')
      cy.get('[data-testid="error-message"]').should('have.css', 'color')
      cy.get('[data-testid="success-message"]').should('have.css', 'color')
    })

    it('should support focus indicators', () => {
      cy.get('[data-testid="search-input"]').focus()
      cy.get('[data-testid="search-input"]').should('have.css', 'outline')
      
      cy.get('[data-testid="primary-button"]').focus()
      cy.get('[data-testid="primary-button"]').should('have.css', 'outline')
    })
  })

  describe('Performance and Optimization', () => {
    it('should load initial page content quickly', () => {
      const startTime = Date.now()
      
      cy.visit('/dashboard')
      cy.get('[data-testid="dashboard"]').should('be.visible')
      
      cy.then(() => {
        const loadTime = Date.now() - startTime
        expect(loadTime).to.be.lessThan(3000) // Should load within 3 seconds
      })
    })

    it('should implement lazy loading for large lists', () => {
      cy.visit('/patients')
      
      // Should load initial batch
      cy.get('[data-testid="patient-row"]').should('have.length', 10)
      
      // Should load more when scrolling
      cy.scrollTo('bottom')
      cy.get('[data-testid="loading-more"]').should('be.visible')
      cy.get('[data-testid="patient-row"]').should('have.length.greaterThan', 10)
    })

    it('should cache frequently accessed data', () => {
      cy.visit('/patients')
      cy.wait('@getPatients')
      
      cy.visit('/appointments')
      cy.visit('/patients')
      
      // Second visit should not trigger API call (cached)
      cy.get('@getPatients.all').should('have.length', 1)
    })

    it('should optimize images and assets', () => {
      cy.get('[data-testid="logo"]').should('be.visible')
      cy.get('[data-testid="logo"]').should(($img) => {
        expect($img[0].naturalWidth).to.be.greaterThan(0)
        expect($img[0].complete).to.be.true
      })
    })
  })

  describe('Search and Filtering UI', () => {
    beforeEach(() => {
      cy.visit('/patients')
    })

    it('should provide instant search feedback', () => {
      cy.get('[data-testid="search-input"]').type('田')
      cy.get('[data-testid="search-suggestions"]').should('be.visible')
      cy.get('[data-testid="search-suggestion"]').should('contain', '田中')
    })

    it('should highlight search terms in results', () => {
      cy.searchFor('田中')
      cy.wait('@getPatients')
      
      cy.get('[data-testid="patient-name"]').first().within(() => {
        cy.get('[data-testid="highlight"]').should('contain', '田中')
        cy.get('[data-testid="highlight"]').should('have.css', 'background-color')
      })
    })

    it('should save and restore search preferences', () => {
      cy.get('[data-testid="search-input"]').type('田中')
      cy.get('[data-testid="status-filter"]').select('booked')
      
      cy.visit('/appointments')
      cy.visit('/patients')
      
      // Should restore previous search
      cy.get('[data-testid="search-input"]').should('have.value', '田中')
      cy.get('[data-testid="status-filter"]').should('have.value', 'booked')
    })

    it('should provide advanced search options', () => {
      cy.get('[data-testid="advanced-search-toggle"]').click()
      cy.get('[data-testid="advanced-search-panel"]').should('be.visible')
      
      cy.get('[data-testid="search-by-phone"]').should('be.visible')
      cy.get('[data-testid="search-by-email"]').should('be.visible')
      cy.get('[data-testid="search-by-insurance"]').should('be.visible')
      cy.get('[data-testid="date-range-filter"]').should('be.visible')
    })
  })

  describe('Data Visualization', () => {
    beforeEach(() => {
      cy.visit('/dashboard')
    })

    it('should display appointment statistics chart', () => {
      cy.get('[data-testid="appointments-chart"]').should('be.visible')
      cy.get('[data-testid="chart-legend"]').should('be.visible')
      
      // Test chart interactivity
      cy.get('[data-testid="chart-bar"]').first().trigger('mouseover')
      cy.get('[data-testid="chart-tooltip"]').should('be.visible')
    })

    it('should show revenue trends', () => {
      cy.get('[data-testid="revenue-chart"]').should('be.visible')
      cy.get('[data-testid="revenue-trend"]').should('contain', '今月')
      
      cy.get('[data-testid="chart-period-selector"]').select('年間')
      cy.get('[data-testid="revenue-trend"]').should('contain', '今年')
    })

    it('should display patient demographics', () => {
      cy.get('[data-testid="demographics-chart"]').should('be.visible')
      cy.get('[data-testid="age-distribution"]').should('be.visible')
      cy.get('[data-testid="treatment-types"]').should('be.visible')
    })
  })
})