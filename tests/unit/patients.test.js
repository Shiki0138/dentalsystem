// 🦷 Dental System - Patients Unit Tests
// Tests for patient management functionality

describe('Patients Management', () => {
  beforeEach(() => {
    fetch.mockClear();
    fetch.mockResolvedValue({
      ok: true,
      json: async () => ({
        status: 'success',
        data: mockPatientData
      })
    });
  });

  const mockPatientData = {
    id: 1,
    name: '田中太郎',
    phone: '090-1234-5678',
    email: 'tanaka@example.com',
    birth_date: '1980-01-01',
    address: '東京都渋谷区',
    insurance_number: 'INS123456789',
    emergency_contact: '田中花子',
    emergency_phone: '090-8765-4321',
    medical_history: '',
    allergies: '',
    created_at: '2025-01-01T00:00:00Z'
  };

  describe('Patient Registration', () => {
    test('should register new patient with valid data', async () => {
      const patientForm = {
        name: '佐藤次郎',
        phone: '090-2345-6789',
        email: 'sato@example.com',
        birth_date: '1985-05-15',
        address: '東京都新宿区',
        insurance_number: 'INS987654321'
      };

      const result = await registerPatient(patientForm);
      
      expect(fetch).toHaveBeenCalledWith('/api/v1/patients', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': 'mock-csrf-token'
        },
        body: JSON.stringify({ patient: patientForm })
      });
      
      expect(result.status).toBe('success');
    });

    test('should validate required patient fields', () => {
      const invalidForm = {
        name: '',
        phone: '',
        email: 'invalid-email'
      };

      const validation = validatePatientForm(invalidForm);
      
      expect(validation.isValid).toBe(false);
      expect(validation.errors).toContain('患者名を入力してください');
      expect(validation.errors).toContain('電話番号を入力してください');
      expect(validation.errors).toContain('有効なメールアドレスを入力してください');
    });

    test('should validate phone number format', () => {
      const phoneTests = [
        { phone: '090-1234-5678', valid: true },
        { phone: '080-9876-5432', valid: true },
        { phone: '070-1111-2222', valid: true },
        { phone: '03-1234-5678', valid: true },
        { phone: '1234567890', valid: false },
        { phone: '090-12-34', valid: false },
        { phone: 'abc-defg-hijk', valid: false }
      ];

      phoneTests.forEach(({ phone, valid }) => {
        expect(isValidPhoneNumber(phone)).toBe(valid);
      });
    });

    test('should validate email format', () => {
      const emailTests = [
        { email: 'test@example.com', valid: true },
        { email: 'user.name@domain.co.jp', valid: true },
        { email: 'invalid-email', valid: false },
        { email: '@domain.com', valid: false },
        { email: 'user@', valid: false },
        { email: '', valid: false }
      ];

      emailTests.forEach(({ email, valid }) => {
        expect(isValidEmail(email)).toBe(valid);
      });
    });
  });

  describe('Patient Search', () => {
    test('should search patients by name', async () => {
      const searchQuery = '田中';
      
      await searchPatients(searchQuery);

      expect(fetch).toHaveBeenCalledWith(
        `/api/v1/patients/search?q=${encodeURIComponent(searchQuery)}`
      );
    });

    test('should search patients by phone number', async () => {
      const phoneNumber = '090-1234';
      
      await searchPatientsByPhone(phoneNumber);

      expect(fetch).toHaveBeenCalledWith(
        `/api/v1/patients/search?phone=${encodeURIComponent(phoneNumber)}`
      );
    });

    test('should handle empty search results', async () => {
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          status: 'success',
          data: []
        })
      });

      const result = await searchPatients('存在しない患者');
      
      expect(result.data).toEqual([]);
    });
  });

  describe('Patient Profile Management', () => {
    test('should update patient information', async () => {
      const patientId = 1;
      const updateData = {
        phone: '090-9999-8888',
        email: 'newemail@example.com',
        address: '東京都港区'
      };

      await updatePatient(patientId, updateData);

      expect(fetch).toHaveBeenCalledWith(`/api/v1/patients/${patientId}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': 'mock-csrf-token'
        },
        body: JSON.stringify({ patient: updateData })
      });
    });

    test('should update medical history', async () => {
      const patientId = 1;
      const medicalHistory = '高血圧の既往歴あり';

      await updateMedicalHistory(patientId, medicalHistory);

      expect(fetch).toHaveBeenCalledWith(`/api/v1/patients/${patientId}/medical_history`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': 'mock-csrf-token'
        },
        body: JSON.stringify({ medical_history: medicalHistory })
      });
    });

    test('should update allergy information', async () => {
      const patientId = 1;
      const allergies = 'ペニシリンアレルギー';

      await updateAllergies(patientId, allergies);

      expect(fetch).toHaveBeenCalledWith(`/api/v1/patients/${patientId}/allergies`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': 'mock-csrf-token'
        },
        body: JSON.stringify({ allergies: allergies })
      });
    });
  });

  describe('Patient Duplicate Detection', () => {
    test('should detect duplicate patients by phone', async () => {
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          status: 'duplicate_found',
          data: {
            existing_patient: mockPatientData,
            similarity_score: 0.95
          }
        })
      });

      const duplicateCheck = await checkForDuplicates({
        name: '田中太郎',
        phone: '090-1234-5678'
      });

      expect(duplicateCheck.status).toBe('duplicate_found');
      expect(duplicateCheck.data.similarity_score).toBe(0.95);
    });

    test('should detect similar names with Levenshtein distance', () => {
      const nameTests = [
        { name1: '田中太郎', name2: '田中太朗', similar: true },
        { name1: '佐藤花子', name2: '佐藤華子', similar: true },
        { name1: '山田一郎', name2: '田中太郎', similar: false },
        { name1: 'Smith John', name2: 'Smith Jon', similar: true }
      ];

      nameTests.forEach(({ name1, name2, similar }) => {
        const similarity = calculateNameSimilarity(name1, name2);
        if (similar) {
          expect(similarity).toBeGreaterThan(0.8);
        } else {
          expect(similarity).toBeLessThan(0.8);
        }
      });
    });
  });

  describe('Patient Privacy and Security', () => {
    test('should mask sensitive information in search results', () => {
      const sensitivePatient = {
        ...mockPatientData,
        insurance_number: 'INS123456789',
        medical_history: '糖尿病治療中'
      };

      const maskedPatient = maskSensitiveInfo(sensitivePatient);

      expect(maskedPatient.insurance_number).toBe('INS******789');
      expect(maskedPatient.medical_history).toBe('[医療情報あり]');
      expect(maskedPatient.name).toBe(sensitivePatient.name); // Name should not be masked
    });

    test('should validate access permissions', () => {
      const userRoles = ['admin', 'doctor', 'receptionist', 'guest'];
      const permissions = [
        { role: 'admin', canViewMedical: true, canEdit: true },
        { role: 'doctor', canViewMedical: true, canEdit: true },
        { role: 'receptionist', canViewMedical: false, canEdit: true },
        { role: 'guest', canViewMedical: false, canEdit: false }
      ];

      permissions.forEach(({ role, canViewMedical, canEdit }) => {
        expect(canAccessMedicalInfo(role)).toBe(canViewMedical);
        expect(canEditPatientInfo(role)).toBe(canEdit);
      });
    });
  });
});

// Mock functions for testing
function registerPatient(formData) {
  return fetch('/api/v1/patients', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
    },
    body: JSON.stringify({ patient: formData })
  }).then(response => response.json());
}

function validatePatientForm(formData) {
  const errors = [];
  
  if (!formData.name?.trim()) errors.push('患者名を入力してください');
  if (!formData.phone?.trim()) errors.push('電話番号を入力してください');
  if (formData.email && !isValidEmail(formData.email)) errors.push('有効なメールアドレスを入力してください');
  if (formData.phone && !isValidPhoneNumber(formData.phone)) errors.push('有効な電話番号を入力してください');
  
  return {
    isValid: errors.length === 0,
    errors
  };
}

function isValidPhoneNumber(phone) {
  // Japanese phone number patterns
  const patterns = [
    /^0[789]0-\d{4}-\d{4}$/, // Mobile: 090-1234-5678
    /^0[1-9]-\d{4}-\d{4}$/,  // Landline: 03-1234-5678
    /^0\d{2}-\d{3}-\d{4}$/   // Landline: 045-123-4567
  ];
  
  return patterns.some(pattern => pattern.test(phone));
}

function isValidEmail(email) {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

function searchPatients(query) {
  return fetch(`/api/v1/patients/search?q=${encodeURIComponent(query)}`);
}

function searchPatientsByPhone(phone) {
  return fetch(`/api/v1/patients/search?phone=${encodeURIComponent(phone)}`);
}

function updatePatient(id, data) {
  return fetch(`/api/v1/patients/${id}`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
    },
    body: JSON.stringify({ patient: data })
  });
}

function updateMedicalHistory(id, medicalHistory) {
  return fetch(`/api/v1/patients/${id}/medical_history`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
    },
    body: JSON.stringify({ medical_history: medicalHistory })
  });
}

function updateAllergies(id, allergies) {
  return fetch(`/api/v1/patients/${id}/allergies`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
    },
    body: JSON.stringify({ allergies: allergies })
  });
}

function checkForDuplicates(patientData) {
  return fetch('/api/v1/patients/check_duplicates', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
    },
    body: JSON.stringify({ patient: patientData })
  }).then(response => response.json());
}

function calculateNameSimilarity(name1, name2) {
  // Simple Levenshtein distance implementation
  const longer = name1.length > name2.length ? name1 : name2;
  const shorter = name1.length > name2.length ? name2 : name1;
  
  if (longer.length === 0) return 1.0;
  
  const distance = levenshteinDistance(longer, shorter);
  return (longer.length - distance) / longer.length;
}

function levenshteinDistance(str1, str2) {
  const matrix = [];
  
  for (let i = 0; i <= str2.length; i++) {
    matrix[i] = [i];
  }
  
  for (let j = 0; j <= str1.length; j++) {
    matrix[0][j] = j;
  }
  
  for (let i = 1; i <= str2.length; i++) {
    for (let j = 1; j <= str1.length; j++) {
      if (str2.charAt(i - 1) === str1.charAt(j - 1)) {
        matrix[i][j] = matrix[i - 1][j - 1];
      } else {
        matrix[i][j] = Math.min(
          matrix[i - 1][j - 1] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j] + 1
        );
      }
    }
  }
  
  return matrix[str2.length][str1.length];
}

function maskSensitiveInfo(patient) {
  const masked = { ...patient };
  
  // Mask insurance number (show first 3 and last 3 characters)
  if (masked.insurance_number) {
    const insNum = masked.insurance_number;
    masked.insurance_number = insNum.substring(0, 3) + '******' + insNum.substring(insNum.length - 3);
  }
  
  // Mask medical history
  if (masked.medical_history?.trim()) {
    masked.medical_history = '[医療情報あり]';
  }
  
  return masked;
}

function canAccessMedicalInfo(role) {
  return ['admin', 'doctor'].includes(role);
}

function canEditPatientInfo(role) {
  return ['admin', 'doctor', 'receptionist'].includes(role);
}