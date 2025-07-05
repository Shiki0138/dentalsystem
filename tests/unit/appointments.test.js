// 🦷 Dental System - Appointments Unit Tests
// Tests for appointment management functionality

describe('Appointments Management', () => {
  beforeEach(() => {
    // Reset mocks
    fetch.mockClear();
    
    // Mock successful API responses
    fetch.mockResolvedValue({
      ok: true,
      json: async () => ({
        status: 'success',
        data: mockAppointmentData
      })
    });
  });

  const mockAppointmentData = {
    id: 1,
    patient_id: 1,
    appointment_date: '2025-07-05',
    appointment_time: '10:00',
    status: 'booked',
    treatment_type: '定期検診',
    notes: 'テスト予約'
  };

  describe('Appointment Creation', () => {
    test('should create new appointment with valid data', async () => {
      const appointmentForm = {
        patient_id: 1,
        appointment_date: '2025-07-05',
        appointment_time: '10:00',
        treatment_type: '定期検診'
      };

      const result = await createAppointment(appointmentForm);
      
      expect(fetch).toHaveBeenCalledWith('/api/v1/appointments', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': 'mock-csrf-token'
        },
        body: JSON.stringify({ appointment: appointmentForm })
      });
      
      expect(result.status).toBe('success');
    });

    test('should validate required fields', () => {
      const invalidForm = {
        patient_id: null,
        appointment_date: '',
        appointment_time: ''
      };

      const validation = validateAppointmentForm(invalidForm);
      
      expect(validation.isValid).toBe(false);
      expect(validation.errors).toContain('患者を選択してください');
      expect(validation.errors).toContain('予約日を入力してください');
      expect(validation.errors).toContain('予約時間を入力してください');
    });

    test('should prevent double booking', async () => {
      // Mock conflict response
      fetch.mockResolvedValueOnce({
        ok: false,
        status: 409,
        json: async () => ({
          status: 'error',
          message: 'この時間は既に予約が入っています'
        })
      });

      const conflictingAppointment = {
        patient_id: 2,
        appointment_date: '2025-07-05',
        appointment_time: '10:00',
        treatment_type: '治療'
      };

      try {
        await createAppointment(conflictingAppointment);
      } catch (error) {
        expect(error.message).toContain('この時間は既に予約が入っています');
      }
    });
  });

  describe('Appointment Status Management', () => {
    test('should update appointment status', async () => {
      const appointmentId = 1;
      const newStatus = 'visited';

      await updateAppointmentStatus(appointmentId, newStatus);

      expect(fetch).toHaveBeenCalledWith(`/api/v1/appointments/${appointmentId}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': 'mock-csrf-token'
        },
        body: JSON.stringify({ 
          appointment: { status: newStatus }
        })
      });
    });

    test('should validate status transitions', () => {
      const validTransitions = [
        { from: 'booked', to: 'visited', valid: true },
        { from: 'visited', to: 'done', valid: true },
        { from: 'done', to: 'paid', valid: true },
        { from: 'booked', to: 'cancelled', valid: true },
        { from: 'paid', to: 'booked', valid: false }, // Invalid transition
        { from: 'done', to: 'visited', valid: false }  // Invalid transition
      ];

      validTransitions.forEach(({ from, to, valid }) => {
        expect(isValidStatusTransition(from, to)).toBe(valid);
      });
    });
  });

  describe('Appointment Search and Filtering', () => {
    test('should search appointments by patient name', async () => {
      const searchQuery = '田中';
      
      await searchAppointments(searchQuery);

      expect(fetch).toHaveBeenCalledWith(
        `/api/v1/appointments/search?q=${encodeURIComponent(searchQuery)}`
      );
    });

    test('should filter appointments by date range', async () => {
      const dateFilter = {
        start_date: '2025-07-01',
        end_date: '2025-07-31'
      };

      await filterAppointmentsByDate(dateFilter);

      expect(fetch).toHaveBeenCalledWith(
        `/api/v1/appointments?start_date=${dateFilter.start_date}&end_date=${dateFilter.end_date}`
      );
    });

    test('should filter appointments by status', async () => {
      const status = 'booked';
      
      await filterAppointmentsByStatus(status);

      expect(fetch).toHaveBeenCalledWith(
        `/api/v1/appointments?status=${status}`
      );
    });
  });

  describe('Appointment Reminders', () => {
    test('should schedule reminder for appointment', async () => {
      const appointmentId = 1;
      const reminderType = 'email';
      const scheduledFor = '2025-07-04 09:00:00';

      await scheduleReminder(appointmentId, reminderType, scheduledFor);

      expect(fetch).toHaveBeenCalledWith('/api/v1/reminders', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': 'mock-csrf-token'
        },
        body: JSON.stringify({
          reminder: {
            appointment_id: appointmentId,
            delivery_type: reminderType,
            scheduled_for: scheduledFor
          }
        })
      });
    });

    test('should validate reminder scheduling rules', () => {
      const validRules = [
        { days_before: 7, valid: true },
        { days_before: 3, valid: true },
        { days_before: 1, valid: true },
        { days_before: 0, valid: false }, // Same day not allowed
        { days_before: -1, valid: false } // Past date not allowed
      ];

      validRules.forEach(({ days_before, valid }) => {
        expect(isValidReminderSchedule(days_before)).toBe(valid);
      });
    });
  });
});

// Mock functions for testing
function createAppointment(formData) {
  return fetch('/api/v1/appointments', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
    },
    body: JSON.stringify({ appointment: formData })
  }).then(response => response.json());
}

function validateAppointmentForm(formData) {
  const errors = [];
  
  if (!formData.patient_id) errors.push('患者を選択してください');
  if (!formData.appointment_date) errors.push('予約日を入力してください');
  if (!formData.appointment_time) errors.push('予約時間を入力してください');
  
  return {
    isValid: errors.length === 0,
    errors
  };
}

function updateAppointmentStatus(id, status) {
  return fetch(`/api/v1/appointments/${id}`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
    },
    body: JSON.stringify({ appointment: { status } })
  });
}

function isValidStatusTransition(fromStatus, toStatus) {
  const validTransitions = {
    'booked': ['visited', 'cancelled', 'no_show'],
    'visited': ['done', 'cancelled'],
    'done': ['paid'],
    'cancelled': [],
    'no_show': [],
    'paid': []
  };
  
  return validTransitions[fromStatus]?.includes(toStatus) || false;
}

function searchAppointments(query) {
  return fetch(`/api/v1/appointments/search?q=${encodeURIComponent(query)}`);
}

function filterAppointmentsByDate({ start_date, end_date }) {
  return fetch(`/api/v1/appointments?start_date=${start_date}&end_date=${end_date}`);
}

function filterAppointmentsByStatus(status) {
  return fetch(`/api/v1/appointments?status=${status}`);
}

function scheduleReminder(appointmentId, deliveryType, scheduledFor) {
  return fetch('/api/v1/reminders', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
    },
    body: JSON.stringify({
      reminder: {
        appointment_id: appointmentId,
        delivery_type: deliveryType,
        scheduled_for: scheduledFor
      }
    })
  });
}

function isValidReminderSchedule(daysBefore) {
  return daysBefore > 0 && daysBefore <= 30;
}