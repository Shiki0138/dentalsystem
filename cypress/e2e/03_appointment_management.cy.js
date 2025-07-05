// 🦷 Dental System - Appointment Management E2E Tests

describe('Appointment Management', () => {
  beforeEach(() => {
    cy.login()
    cy.visit('/appointments')
    cy.waitForLoading()
  })

  describe('Appointment Creation', () => {
    it('should create a new appointment with valid data', () => {
      const newAppointment = {
        patientName: '田中太郎',
        date: '2025-07-10',
        time: '14:00',
        treatmentType: '定期検診',
        notes: 'E2Eテスト予約'
      }

      cy.get('[data-testid="new-appointment-btn"]').click()
      cy.get('[data-testid="appointment-form"]').should('be.visible')
      
      cy.get('[data-testid="patient-select"]').select(newAppointment.patientName)
      cy.get('[data-testid="appointment-date"]').type(newAppointment.date)
      cy.get('[data-testid="appointment-time"]').select(newAppointment.time)
      cy.get('[data-testid="treatment-type"]').select(newAppointment.treatmentType)
      cy.get('[data-testid="appointment-notes"]').type(newAppointment.notes)
      
      cy.get('[data-testid="appointment-submit"]').click()
      cy.wait('@createAppointment')
      
      cy.get('[data-testid="success-message"]').should('contain', '予約を作成しました')
      cy.url().should('include', '/appointments/')
    })

    it('should validate required fields', () => {
      cy.get('[data-testid="new-appointment-btn"]').click()
      cy.get('[data-testid="appointment-submit"]').click()
      
      cy.get('[data-testid="validation-errors"]').should('be.visible')
      cy.get('[data-testid="patient-select"]').should('have.class', 'is-invalid')
      cy.get('[data-testid="appointment-date"]').should('have.class', 'is-invalid')
      cy.get('[data-testid="appointment-time"]').should('have.class', 'is-invalid')
    })

    it('should prevent double booking', () => {
      cy.intercept('POST', '/api/v1/appointments', {
        statusCode: 409,
        body: {
          status: 'error',
          message: 'この時間は既に予約が入っています',
          conflicting_appointment: {
            id: 1,
            patient_name: '佐藤花子',
            appointment_time: '10:00'
          }
        }
      }).as('conflictingAppointment')

      cy.get('[data-testid="new-appointment-btn"]').click()
      cy.get('[data-testid="patient-select"]').select('田中太郎')
      cy.get('[data-testid="appointment-date"]').type('2025-07-05')
      cy.get('[data-testid="appointment-time"]').select('10:00')
      cy.get('[data-testid="treatment-type"]').select('定期検診')
      cy.get('[data-testid="appointment-submit"]').click()
      
      cy.wait('@conflictingAppointment')
      cy.get('[data-testid="conflict-warning"]').should('be.visible')
      cy.get('[data-testid="conflict-warning"]').should('contain', 'この時間は既に予約が入っています')
      cy.get('[data-testid="suggested-times"]').should('be.visible')
    })

    it('should validate appointment date is in the future', () => {
      cy.get('[data-testid="new-appointment-btn"]').click()
      
      const pastDate = '2024-01-01'
      cy.get('[data-testid="appointment-date"]').type(pastDate)
      cy.get('[data-testid="appointment-submit"]').click()
      
      cy.get('[data-testid="validation-errors"]').should('contain', '予約日は今日以降を選択してください')
    })

    it('should show available time slots', () => {
      cy.intercept('GET', '/api/v1/appointments/available_slots*', {
        status: 'success',
        data: {
          morning: ['09:00', '09:30', '10:00', '10:30', '11:00'],
          afternoon: ['14:00', '14:30', '15:00', '15:30', '16:00'],
          unavailable: ['10:00', '15:00']
        }
      }).as('availableSlots')

      cy.get('[data-testid="new-appointment-btn"]').click()
      cy.get('[data-testid="appointment-date"]').type('2025-07-10')
      
      cy.wait('@availableSlots')
      cy.get('[data-testid="time-slots"]').should('be.visible')
      cy.get('[data-testid="unavailable-slot"]').should('have.length', 2)
      cy.get('[data-testid="available-slot"]').should('have.length.greaterThan', 5)
    })
  })

  describe('Appointment Calendar View', () => {
    beforeEach(() => {
      cy.get('[data-testid="calendar-view"]').click()
      cy.waitForLoading()
    })

    it('should display appointments in calendar format', () => {
      cy.get('[data-testid="calendar"]').should('be.visible')
      cy.get('[data-testid="calendar-appointment"]').should('have.length.greaterThan', 0)
      
      // Check for appointment details in calendar
      cy.get('[data-testid="calendar-appointment"]').first().within(() => {
        cy.get('[data-testid="appointment-time"]').should('not.be.empty')
        cy.get('[data-testid="patient-name"]').should('not.be.empty')
      })
    })

    it('should navigate between months', () => {
      cy.get('[data-testid="prev-month"]').click()
      cy.get('[data-testid="current-month"]').should('contain', '2025年6月')
      
      cy.get('[data-testid="next-month"]').click()
      cy.get('[data-testid="current-month"]').should('contain', '2025年7月')
    })

    it('should create appointment by clicking on calendar date', () => {
      cy.get('[data-testid="calendar-date"][data-date="2025-07-15"]').click()
      cy.get('[data-testid="appointment-form"]').should('be.visible')
      cy.get('[data-testid="appointment-date"]').should('have.value', '2025-07-15')
    })

    it('should show day view with hourly slots', () => {
      cy.get('[data-testid="calendar-date"][data-date="2025-07-05"]').click()
      cy.get('[data-testid="day-view"]').should('be.visible')
      
      cy.get('[data-testid="time-slot"]').should('have.length', 18) // 9:00-17:30 (30min slots)
      cy.get('[data-testid="booked-slot"]').should('have.length.greaterThan', 0)
    })
  })

  describe('Appointment Status Management', () => {
    beforeEach(() => {
      cy.get('[data-testid="list-view"]').click()
      cy.waitForLoading()
    })

    it('should update appointment status', () => {
      cy.get('[data-testid="appointment-row"]').first().within(() => {
        cy.get('[data-testid="status-dropdown"]').select('visited')
        cy.get('[data-testid="update-status"]').click()
      })
      
      cy.get('[data-testid="success-message"]').should('contain', 'ステータスを更新しました')
      cy.get('[data-testid="appointment-row"]').first().should('contain', '来院済み')
    })

    it('should prevent invalid status transitions', () => {
      // Find an appointment with 'paid' status and try to change to 'booked'
      cy.get('[data-testid="appointment-row"]')
        .contains('[data-status="paid"]')
        .parent()
        .within(() => {
          cy.get('[data-testid="status-dropdown"]').should('not.contain.value', 'booked')
        })
    })

    it('should track status change history', () => {
      cy.get('[data-testid="appointment-row"]').first().click()
      cy.get('[data-testid="status-history"]').should('be.visible')
      
      cy.get('[data-testid="status-change"]').should('have.length.greaterThan', 0)
      cy.get('[data-testid="status-change"]').first().within(() => {
        cy.get('[data-testid="change-date"]').should('not.be.empty')
        cy.get('[data-testid="changed-by"]').should('not.be.empty')
        cy.get('[data-testid="old-status"]').should('not.be.empty')
        cy.get('[data-testid="new-status"]').should('not.be.empty')
      })
    })

    it('should allow batch status updates', () => {
      cy.get('[data-testid="select-all"]').check()
      cy.get('[data-testid="bulk-actions"]').should('be.visible')
      cy.get('[data-testid="bulk-status-update"]').select('visited')
      cy.get('[data-testid="apply-bulk-action"]').click()
      
      cy.get('[data-testid="confirmation-modal"]').should('be.visible')
      cy.get('[data-testid="confirm-bulk-update"]').click()
      
      cy.get('[data-testid="success-message"]').should('contain', '一括更新が完了しました')
    })
  })

  describe('Appointment Search and Filtering', () => {
    it('should search appointments by patient name', () => {
      cy.searchFor('田中')
      cy.wait('@getAppointments')
      
      cy.get('[data-testid="appointment-table"]').should('be.visible')
      cy.get('[data-testid="appointment-row"]').each(($row) => {
        cy.wrap($row).should('contain', '田中')
      })
    })

    it('should filter appointments by status', () => {
      cy.get('[data-testid="status-filter"]').select('booked')
      cy.wait('@getAppointments')
      
      cy.get('[data-testid="appointment-row"]').each(($row) => {
        cy.wrap($row).find('[data-testid="status-badge"]').should('contain', '予約済み')
      })
    })

    it('should filter appointments by date range', () => {
      cy.get('[data-testid="date-filter"]').click()
      cy.get('[data-testid="start-date"]').type('2025-07-01')
      cy.get('[data-testid="end-date"]').type('2025-07-31')
      cy.get('[data-testid="apply-date-filter"]').click()
      
      cy.wait('@getAppointments')
      cy.get('[data-testid="appointment-row"]').should('have.length.greaterThan', 0)
    })

    it('should filter appointments by treatment type', () => {
      cy.get('[data-testid="treatment-filter"]').select('定期検診')
      cy.wait('@getAppointments')
      
      cy.get('[data-testid="appointment-row"]').each(($row) => {
        cy.wrap($row).should('contain', '定期検診')
      })
    })

    it('should combine multiple filters', () => {
      cy.get('[data-testid="status-filter"]').select('booked')
      cy.get('[data-testid="treatment-filter"]').select('定期検診')
      cy.searchFor('田中')
      
      cy.wait('@getAppointments')
      cy.get('[data-testid="active-filters"]').should('contain', '3件のフィルターが適用中')
    })
  })

  describe('Appointment Reminders', () => {
    beforeEach(() => {
      cy.get('[data-testid="appointment-row"]').first().click()
      cy.waitForLoading()
    })

    it('should schedule email reminder', () => {
      cy.get('[data-testid="reminders-section"]').should('be.visible')
      cy.get('[data-testid="add-reminder"]').click()
      
      cy.get('[data-testid="reminder-type"]').select('email')
      cy.get('[data-testid="reminder-days-before"]').select('1')
      cy.get('[data-testid="save-reminder"]').click()
      
      cy.get('[data-testid="success-message"]').should('contain', 'リマインダーを設定しました')
      cy.get('[data-testid="reminder-list"]').should('contain', 'メール')
    })

    it('should schedule SMS reminder', () => {
      cy.get('[data-testid="add-reminder"]').click()
      
      cy.get('[data-testid="reminder-type"]').select('sms')
      cy.get('[data-testid="reminder-days-before"]').select('3')
      cy.get('[data-testid="save-reminder"]').click()
      
      cy.get('[data-testid="success-message"]').should('contain', 'リマインダーを設定しました')
      cy.get('[data-testid="reminder-list"]').should('contain', 'SMS')
    })

    it('should show reminder history', () => {
      cy.get('[data-testid="reminder-history"]').should('be.visible')
      cy.get('[data-testid="sent-reminder"]').should('have.length.greaterThan', 0)
      
      cy.get('[data-testid="sent-reminder"]').first().within(() => {
        cy.get('[data-testid="sent-date"]').should('not.be.empty')
        cy.get('[data-testid="delivery-status"]').should('not.be.empty')
      })
    })

    it('should delete scheduled reminder', () => {
      cy.get('[data-testid="reminder-list"]').within(() => {
        cy.get('[data-testid="delete-reminder"]').first().click()
      })
      
      cy.get('[data-testid="confirmation-modal"]').should('be.visible')
      cy.get('[data-testid="confirm-delete"]').click()
      
      cy.get('[data-testid="success-message"]').should('contain', 'リマインダーを削除しました')
    })
  })

  describe('Appointment Notes and Documentation', () => {
    beforeEach(() => {
      cy.get('[data-testid="appointment-row"]').first().click()
      cy.waitForLoading()
    })

    it('should add appointment notes', () => {
      const notes = 'E2Eテストで追加されたメモです。患者の状態は良好。'
      
      cy.get('[data-testid="notes-section"]').should('be.visible')
      cy.get('[data-testid="add-note"]').click()
      cy.get('[data-testid="note-textarea"]').type(notes)
      cy.get('[data-testid="save-note"]').click()
      
      cy.get('[data-testid="success-message"]').should('contain', 'メモを追加しました')
      cy.get('[data-testid="note-list"]').should('contain', notes)
    })

    it('should edit existing notes', () => {
      const updatedNotes = '更新されたメモ内容です。'
      
      cy.get('[data-testid="note-item"]').first().within(() => {
        cy.get('[data-testid="edit-note"]').click()
      })
      
      cy.get('[data-testid="note-textarea"]').clear().type(updatedNotes)
      cy.get('[data-testid="save-note"]').click()
      
      cy.get('[data-testid="success-message"]').should('contain', 'メモを更新しました')
      cy.get('[data-testid="note-list"]').should('contain', updatedNotes)
    })

    it('should show note history with timestamps', () => {
      cy.get('[data-testid="note-item"]').each(($note) => {
        cy.wrap($note).within(() => {
          cy.get('[data-testid="note-timestamp"]').should('not.be.empty')
          cy.get('[data-testid="note-author"]').should('not.be.empty')
        })
      })
    })
  })

  describe('Performance and Loading', () => {
    it('should load appointments quickly', () => {
      const startTime = Date.now()
      
      cy.visit('/appointments')
      cy.waitForLoading()
      cy.get('[data-testid="appointment-table"]').should('be.visible')
      
      cy.then(() => {
        const loadTime = Date.now() - startTime
        expect(loadTime).to.be.lessThan(3000) // Should load within 3 seconds
      })
    })

    it('should handle large appointment lists efficiently', () => {
      // Mock large dataset
      cy.intercept('GET', '/api/v1/appointments*', {
        fixture: 'large_appointments.json'
      }).as('largeAppointments')
      
      cy.visit('/appointments')
      cy.wait('@largeAppointments')
      
      // Should implement pagination or virtual scrolling
      cy.get('[data-testid="pagination"]').should('be.visible')
      cy.get('[data-testid="page-size-selector"]').should('be.visible')
    })

    it('should show loading states during operations', () => {
      cy.get('[data-testid="new-appointment-btn"]').click()
      cy.get('[data-testid="patient-select"]').select('田中太郎')
      cy.get('[data-testid="appointment-date"]').type('2025-07-10')
      cy.get('[data-testid="appointment-time"]').select('14:00')
      cy.get('[data-testid="treatment-type"]').select('定期検診')
      
      // Intercept with delay to test loading state
      cy.intercept('POST', '/api/v1/appointments', {
        delay: 2000,
        fixture: 'appointment_created.json'
      }).as('slowCreate')
      
      cy.get('[data-testid="appointment-submit"]').click()
      cy.get('[data-testid="loading-spinner"]').should('be.visible')
      cy.get('[data-testid="appointment-submit"]').should('be.disabled')
      
      cy.wait('@slowCreate')
      cy.get('[data-testid="loading-spinner"]').should('not.exist')
    })
  })
})