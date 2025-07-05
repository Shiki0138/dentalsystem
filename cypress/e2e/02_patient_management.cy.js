// 🦷 Dental System - Patient Management E2E Tests

describe('Patient Management', () => {
  beforeEach(() => {
    cy.login()
    cy.visit('/patients')
    cy.waitForLoading()
  })

  describe('Patient Registration', () => {
    it('should register a new patient with valid data', () => {
      const newPatient = {
        name: 'E2Eテスト患者',
        phone: '090-1111-2222',
        email: 'e2e.test@example.com',
        birthDate: '1990-01-01',
        address: '東京都港区テスト1-1-1',
        insuranceNumber: 'INS123456789'
      }

      cy.get('[data-testid="new-patient-btn"]').click()
      cy.get('[data-testid="patient-form"]').should('be.visible')
      
      cy.get('[data-testid="patient-name-input"]').type(newPatient.name)
      cy.get('[data-testid="patient-phone-input"]').type(newPatient.phone)
      cy.get('[data-testid="patient-email-input"]').type(newPatient.email)
      cy.get('[data-testid="patient-birth-date"]').type(newPatient.birthDate)
      cy.get('[data-testid="patient-address"]').type(newPatient.address)
      cy.get('[data-testid="patient-insurance"]').type(newPatient.insuranceNumber)
      
      cy.get('[data-testid="patient-submit"]').click()
      cy.wait('@createPatient')
      
      cy.get('[data-testid="success-message"]').should('contain', '患者を登録しました')
      cy.url().should('include', '/patients/')
      cy.get('[data-testid="patient-name"]').should('contain', newPatient.name)
    })

    it('should validate required fields', () => {
      cy.get('[data-testid="new-patient-btn"]').click()
      cy.get('[data-testid="patient-submit"]').click()
      
      cy.get('[data-testid="validation-errors"]').should('be.visible')
      cy.get('[data-testid="patient-name-input"]').should('have.class', 'is-invalid')
      cy.get('[data-testid="patient-phone-input"]').should('have.class', 'is-invalid')
    })

    it('should validate phone number format', () => {
      cy.get('[data-testid="new-patient-btn"]').click()
      
      // Test invalid phone formats
      const invalidPhones = ['123456789', '090-12-34', 'abc-defg-hijk']
      
      invalidPhones.forEach(phone => {
        cy.get('[data-testid="patient-phone-input"]').clear().type(phone)
        cy.get('[data-testid="patient-submit"]').click()
        cy.get('[data-testid="validation-errors"]').should('contain', '有効な電話番号を入力してください')
      })
    })

    it('should validate email format', () => {
      cy.get('[data-testid="new-patient-btn"]').click()
      
      cy.get('[data-testid="patient-name-input"]').type('テスト患者')
      cy.get('[data-testid="patient-phone-input"]').type('090-1234-5678')
      cy.get('[data-testid="patient-email-input"]').type('invalid-email')
      cy.get('[data-testid="patient-submit"]').click()
      
      cy.get('[data-testid="validation-errors"]').should('contain', '有効なメールアドレスを入力してください')
    })

    it('should detect duplicate patients', () => {
      cy.intercept('POST', '/api/v1/patients', {
        statusCode: 409,
        body: {
          status: 'duplicate_found',
          message: '同様の患者が既に登録されています',
          existing_patient: {
            id: 1,
            name: '田中太郎',
            phone: '090-1234-5678'
          }
        }
      }).as('duplicatePatient')

      cy.get('[data-testid="new-patient-btn"]').click()
      cy.get('[data-testid="patient-name-input"]').type('田中太郎')
      cy.get('[data-testid="patient-phone-input"]').type('090-1234-5678')
      cy.get('[data-testid="patient-submit"]').click()
      
      cy.wait('@duplicatePatient')
      cy.get('[data-testid="duplicate-warning"]').should('be.visible')
      cy.get('[data-testid="duplicate-warning"]').should('contain', '同様の患者が既に登録されています')
    })
  })

  describe('Patient Search and Filtering', () => {
    it('should search patients by name', () => {
      cy.searchFor('田中', 'name')
      cy.wait('@getPatients')
      
      cy.get('[data-testid="patient-table"]').should('be.visible')
      cy.get('[data-testid="patient-row"]').should('contain', '田中')
      cy.get('[data-testid="search-results-count"]').should('contain', '検索結果:')
    })

    it('should search patients by phone number', () => {
      cy.searchFor('090-1234', 'phone')
      cy.wait('@getPatients')
      
      cy.get('[data-testid="patient-table"]').should('be.visible')
      cy.get('[data-testid="patient-row"]').should('contain', '090-1234')
    })

    it('should handle empty search results', () => {
      cy.intercept('GET', '/api/v1/patients/search*', {
        status: 'success',
        data: [],
        meta: { total: 0 }
      }).as('emptySearch')

      cy.searchFor('存在しない患者')
      cy.wait('@emptySearch')
      
      cy.get('[data-testid="empty-results"]').should('be.visible')
      cy.get('[data-testid="empty-results"]').should('contain', '検索結果が見つかりませんでした')
    })

    it('should clear search results', () => {
      cy.searchFor('田中')
      cy.wait('@getPatients')
      
      cy.get('[data-testid="clear-search"]').click()
      cy.get('[data-testid="search-input"]').should('have.value', '')
      cy.get('[data-testid="patient-table"]').should('contain', '佐藤') // Should show all patients
    })

    it('should filter patients by registration date', () => {
      cy.get('[data-testid="date-filter"]').click()
      cy.get('[data-testid="start-date"]').type('2025-01-01')
      cy.get('[data-testid="end-date"]').type('2025-01-31')
      cy.get('[data-testid="apply-filter"]').click()
      
      cy.wait('@getPatients')
      cy.get('[data-testid="patient-table"]').should('be.visible')
    })
  })

  describe('Patient Profile Management', () => {
    beforeEach(() => {
      cy.get('[data-testid="patient-row"]').first().click()
      cy.waitForLoading()
    })

    it('should display patient profile information', () => {
      cy.get('[data-testid="patient-profile"]').should('be.visible')
      cy.get('[data-testid="patient-name"]').should('not.be.empty')
      cy.get('[data-testid="patient-phone"]').should('not.be.empty')
      cy.get('[data-testid="patient-email"]').should('not.be.empty')
    })

    it('should edit patient basic information', () => {
      cy.get('[data-testid="edit-patient-btn"]').click()
      cy.get('[data-testid="patient-form"]').should('be.visible')
      
      const updatedPhone = '090-9999-8888'
      cy.get('[data-testid="patient-phone-input"]').clear().type(updatedPhone)
      cy.get('[data-testid="save-patient"]').click()
      
      cy.get('[data-testid="success-message"]').should('contain', '患者情報を更新しました')
      cy.get('[data-testid="patient-phone"]').should('contain', updatedPhone)
    })

    it('should update medical history', () => {
      cy.get('[data-testid="medical-history-section"]').should('be.visible')
      cy.get('[data-testid="edit-medical-history"]').click()
      
      const medicalHistory = '高血圧の既往歴あり。定期的に血圧測定が必要。'
      cy.get('[data-testid="medical-history-textarea"]').clear().type(medicalHistory)
      cy.get('[data-testid="save-medical-history"]').click()
      
      cy.get('[data-testid="success-message"]').should('contain', '医療履歴を更新しました')
      cy.get('[data-testid="medical-history-display"]').should('contain', medicalHistory)
    })

    it('should update allergy information', () => {
      cy.get('[data-testid="allergies-section"]').should('be.visible')
      cy.get('[data-testid="edit-allergies"]').click()
      
      const allergies = 'ペニシリンアレルギー、局所麻酔薬アレルギー'
      cy.get('[data-testid="allergies-textarea"]').clear().type(allergies)
      cy.get('[data-testid="save-allergies"]').click()
      
      cy.get('[data-testid="success-message"]').should('contain', 'アレルギー情報を更新しました')
      cy.get('[data-testid="allergies-display"]').should('contain', allergies)
    })

    it('should display patient appointment history', () => {
      cy.get('[data-testid="appointment-history"]').should('be.visible')
      cy.get('[data-testid="appointment-history-table"]').should('be.visible')
      
      // Check if appointments are displayed
      cy.get('[data-testid="appointment-row"]').should('have.length.greaterThan', 0)
      cy.get('[data-testid="appointment-date"]').first().should('not.be.empty')
      cy.get('[data-testid="appointment-status"]').first().should('not.be.empty')
    })
  })

  describe('Patient Privacy and Security', () => {
    it('should mask sensitive information in patient list', () => {
      cy.get('[data-testid="patient-table"]').should('be.visible')
      
      // Insurance numbers should be masked
      cy.get('[data-testid="insurance-number"]').each(($el) => {
        cy.wrap($el).should('contain', '***')
      })
    })

    it('should require doctor role to view medical information', () => {
      // Mock receptionist role
      cy.window().then((win) => {
        win.localStorage.setItem('user_role', 'receptionist')
      })
      
      cy.reload()
      cy.get('[data-testid="patient-row"]').first().click()
      
      cy.get('[data-testid="medical-history-section"]').should('not.exist')
      cy.get('[data-testid="allergies-section"]').should('not.exist')
      cy.get('[data-testid="access-denied"]').should('contain', '医療情報の閲覧権限がありません')
    })

    it('should log patient access for audit trail', () => {
      cy.intercept('POST', '/api/v1/audit/patient_access', {
        status: 'success'
      }).as('auditLog')
      
      cy.get('[data-testid="patient-row"]').first().click()
      cy.wait('@auditLog')
    })
  })

  describe('Responsive Design', () => {
    it('should work on mobile devices', () => {
      cy.checkResponsive()
      
      // Test mobile-specific features
      cy.viewport(375, 667)
      cy.get('[data-testid="mobile-patient-card"]').should('be.visible')
      cy.get('[data-testid="mobile-search"]').should('be.visible')
    })

    it('should maintain functionality on tablet', () => {
      cy.viewport(768, 1024)
      cy.get('[data-testid="patient-table"]').should('be.visible')
      cy.get('[data-testid="sidebar"]').should('be.visible')
    })
  })

  describe('Patient Data Export', () => {
    it('should export patient list to CSV', () => {
      cy.get('[data-testid="export-patients"]').click()
      cy.get('[data-testid="export-csv"]').click()
      
      // Note: In a real test, you'd verify the download
      cy.get('[data-testid="export-success"]').should('contain', 'エクスポートを開始しました')
    })

    it('should respect privacy settings in export', () => {
      cy.get('[data-testid="export-patients"]').click()
      cy.get('[data-testid="privacy-options"]').should('be.visible')
      cy.get('[data-testid="mask-sensitive-data"]').should('be.checked')
    })
  })
})