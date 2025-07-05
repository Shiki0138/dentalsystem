// 🦷 Dental System - Authentication Unit Tests
// Tests for user authentication and authorization

describe('Authentication System', () => {
  beforeEach(() => {
    fetch.mockClear();
    localStorage.clear();
    sessionStorage.clear();
  });

  const mockUser = {
    id: 1,
    email: 'doctor@dental.com',
    role: 'doctor',
    name: '歯科医師',
    two_factor_enabled: true
  };

  describe('Login Process', () => {
    test('should login with valid credentials', async () => {
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          status: 'success',
          user: mockUser,
          token: 'jwt-token-123'
        })
      });

      const credentials = {
        email: 'doctor@dental.com',
        password: 'securepassword123'
      };

      const result = await login(credentials);
      
      expect(fetch).toHaveBeenCalledWith('/api/v1/auth/login', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': 'mock-csrf-token'
        },
        body: JSON.stringify({ user: credentials })
      });
      
      expect(result.status).toBe('success');
      expect(result.user.email).toBe('doctor@dental.com');
    });

    test('should reject invalid credentials', async () => {
      fetch.mockResolvedValueOnce({
        ok: false,
        status: 401,
        json: async () => ({
          status: 'error',
          message: 'メールアドレスまたはパスワードが正しくありません'
        })
      });

      const invalidCredentials = {
        email: 'doctor@dental.com',
        password: 'wrongpassword'
      };

      try {
        await login(invalidCredentials);
      } catch (error) {
        expect(error.message).toContain('メールアドレスまたはパスワードが正しくありません');
      }
    });

    test('should validate email format', () => {
      const emailTests = [
        { email: 'doctor@dental.com', valid: true },
        { email: 'admin@clinic.co.jp', valid: true },
        { email: 'invalid-email', valid: false },
        { email: '@dental.com', valid: false },
        { email: 'doctor@', valid: false },
        { email: '', valid: false }
      ];

      emailTests.forEach(({ email, valid }) => {
        expect(isValidEmail(email)).toBe(valid);
      });
    });

    test('should validate password strength', () => {
      const passwordTests = [
        { password: 'StrongPass123!', valid: true },
        { password: 'ComplexP@ssw0rd', valid: true },
        { password: 'weak', valid: false },
        { password: '12345678', valid: false },
        { password: 'onlylowercase', valid: false },
        { password: 'ONLYUPPERCASE', valid: false },
        { password: 'NoNumbers!', valid: false }
      ];

      passwordTests.forEach(({ password, valid }) => {
        expect(isValidPassword(password)).toBe(valid);
      });
    });
  });

  describe('Two-Factor Authentication (2FA)', () => {
    test('should enable 2FA for user', async () => {
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          status: 'success',
          qr_code: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
          backup_codes: ['123456789', '987654321']
        })
      });

      const result = await enable2FA();
      
      expect(fetch).toHaveBeenCalledWith('/api/v1/auth/2fa/enable', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': 'mock-csrf-token'
        }
      });
      
      expect(result.status).toBe('success');
      expect(result.qr_code).toBeTruthy();
      expect(result.backup_codes).toHaveLength(2);
    });

    test('should verify 2FA code', async () => {
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          status: 'success',
          verified: true
        })
      });

      const code = '123456';
      const result = await verify2FA(code);
      
      expect(fetch).toHaveBeenCalledWith('/api/v1/auth/2fa/verify', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': 'mock-csrf-token'
        },
        body: JSON.stringify({ code: code })
      });
      
      expect(result.verified).toBe(true);
    });

    test('should validate 2FA code format', () => {
      const codeTests = [
        { code: '123456', valid: true },
        { code: '000000', valid: true },
        { code: '999999', valid: true },
        { code: '12345', valid: false }, // Too short
        { code: '1234567', valid: false }, // Too long
        { code: 'abcdef', valid: false }, // Non-numeric
        { code: '12 34 56', valid: false }, // Contains spaces
        { code: '', valid: false }
      ];

      codeTests.forEach(({ code, valid }) => {
        expect(isValid2FACode(code)).toBe(valid);
      });
    });

    test('should handle backup codes', async () => {
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          status: 'success',
          verified: true,
          backup_code_used: true
        })
      });

      const backupCode = '123456789';
      const result = await verifyBackupCode(backupCode);
      
      expect(result.verified).toBe(true);
      expect(result.backup_code_used).toBe(true);
    });
  });

  describe('Session Management', () => {
    test('should store session data securely', () => {
      const sessionData = {
        user_id: 1,
        role: 'doctor',
        expires_at: new Date(Date.now() + 8 * 60 * 60 * 1000).toISOString() // 8 hours
      };

      storeSession(sessionData);
      
      expect(sessionStorage.getItem('user_session')).toBeTruthy();
      const stored = JSON.parse(sessionStorage.getItem('user_session'));
      expect(stored.user_id).toBe(1);
      expect(stored.role).toBe('doctor');
    });

    test('should validate session expiry', () => {
      const expiredSession = {
        user_id: 1,
        role: 'doctor',
        expires_at: new Date(Date.now() - 1000).toISOString() // Expired 1 second ago
      };

      const validSession = {
        user_id: 1,
        role: 'doctor',
        expires_at: new Date(Date.now() + 8 * 60 * 60 * 1000).toISOString() // Valid for 8 hours
      };

      expect(isSessionValid(expiredSession)).toBe(false);
      expect(isSessionValid(validSession)).toBe(true);
    });

    test('should clear session on logout', async () => {
      // Set up session first
      const sessionData = {
        user_id: 1,
        role: 'doctor',
        expires_at: new Date(Date.now() + 8 * 60 * 60 * 1000).toISOString()
      };
      storeSession(sessionData);

      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          status: 'success',
          message: 'ログアウトしました'
        })
      });

      await logout();
      
      expect(sessionStorage.getItem('user_session')).toBeNull();
      expect(localStorage.getItem('remember_token')).toBeNull();
    });

    test('should auto-refresh session before expiry', async () => {
      const nearExpirySession = {
        user_id: 1,
        role: 'doctor',
        expires_at: new Date(Date.now() + 5 * 60 * 1000).toISOString() // Expires in 5 minutes
      };

      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          status: 'success',
          expires_at: new Date(Date.now() + 8 * 60 * 60 * 1000).toISOString()
        })
      });

      const result = await refreshSession(nearExpirySession);
      
      expect(fetch).toHaveBeenCalledWith('/api/v1/auth/refresh', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': 'mock-csrf-token'
        }
      });
      
      expect(result.status).toBe('success');
    });
  });

  describe('Role-Based Access Control', () => {
    test('should validate admin permissions', () => {
      const roles = ['admin', 'doctor', 'receptionist', 'guest'];
      
      roles.forEach(role => {
        const canManageUsers = hasPermission(role, 'manage_users');
        expect(canManageUsers).toBe(role === 'admin');
      });
    });

    test('should validate doctor permissions', () => {
      const doctorPermissions = [
        'view_medical_records',
        'edit_medical_records',
        'view_appointments',
        'edit_appointments'
      ];

      doctorPermissions.forEach(permission => {
        expect(hasPermission('doctor', permission)).toBe(true);
        expect(hasPermission('receptionist', permission)).toBe(permission.includes('appointments'));
        expect(hasPermission('guest', permission)).toBe(false);
      });
    });

    test('should validate receptionist permissions', () => {
      const receptionistPermissions = [
        'view_appointments',
        'edit_appointments',
        'view_patient_basic_info',
        'schedule_appointments'
      ];

      receptionistPermissions.forEach(permission => {
        expect(hasPermission('receptionist', permission)).toBe(true);
      });

      // Should NOT have medical permissions
      expect(hasPermission('receptionist', 'view_medical_records')).toBe(false);
      expect(hasPermission('receptionist', 'edit_medical_records')).toBe(false);
    });
  });

  describe('Password Security', () => {
    test('should enforce password complexity', () => {
      const requirements = getPasswordRequirements();
      
      expect(requirements).toEqual({
        minLength: 8,
        requireUppercase: true,
        requireLowercase: true,
        requireNumbers: true,
        requireSymbols: true,
        maxAge: 90 // days
      });
    });

    test('should detect common passwords', () => {
      const commonPasswords = [
        'password',
        'password123',
        '12345678',
        'qwerty',
        'admin',
        'dental123'
      ];

      commonPasswords.forEach(password => {
        expect(isCommonPassword(password)).toBe(true);
      });

      expect(isCommonPassword('UniqueP@ssw0rd2024!')).toBe(false);
    });

    test('should handle password reset', async () => {
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          status: 'success',
          message: 'パスワードリセットメールを送信しました'
        })
      });

      const email = 'doctor@dental.com';
      const result = await requestPasswordReset(email);
      
      expect(fetch).toHaveBeenCalledWith('/api/v1/auth/password/reset', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': 'mock-csrf-token'
        },
        body: JSON.stringify({ email: email })
      });
      
      expect(result.status).toBe('success');
    });
  });
});

// Mock functions for testing
function login(credentials) {
  return fetch('/api/v1/auth/login', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
    },
    body: JSON.stringify({ user: credentials })
  }).then(response => {
    if (!response.ok) {
      return response.json().then(err => Promise.reject(new Error(err.message)));
    }
    return response.json();
  });
}

function logout() {
  sessionStorage.clear();
  localStorage.removeItem('remember_token');
  
  return fetch('/api/v1/auth/logout', {
    method: 'DELETE',
    headers: {
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
    }
  }).then(response => response.json());
}

function enable2FA() {
  return fetch('/api/v1/auth/2fa/enable', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
    }
  }).then(response => response.json());
}

function verify2FA(code) {
  return fetch('/api/v1/auth/2fa/verify', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
    },
    body: JSON.stringify({ code: code })
  }).then(response => response.json());
}

function verifyBackupCode(backupCode) {
  return fetch('/api/v1/auth/2fa/backup', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
    },
    body: JSON.stringify({ backup_code: backupCode })
  }).then(response => response.json());
}

function isValidEmail(email) {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

function isValidPassword(password) {
  // At least 8 characters, includes uppercase, lowercase, number, and symbol
  const minLength = password.length >= 8;
  const hasUpper = /[A-Z]/.test(password);
  const hasLower = /[a-z]/.test(password);
  const hasNumber = /\d/.test(password);
  const hasSymbol = /[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/.test(password);
  
  return minLength && hasUpper && hasLower && hasNumber && hasSymbol;
}

function isValid2FACode(code) {
  return /^\d{6}$/.test(code);
}

function storeSession(sessionData) {
  sessionStorage.setItem('user_session', JSON.stringify(sessionData));
}

function isSessionValid(sessionData) {
  if (!sessionData || !sessionData.expires_at) return false;
  
  const expiryTime = new Date(sessionData.expires_at);
  const currentTime = new Date();
  
  return expiryTime > currentTime;
}

function refreshSession(sessionData) {
  return fetch('/api/v1/auth/refresh', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
    }
  }).then(response => response.json());
}

function hasPermission(role, permission) {
  const permissions = {
    admin: [
      'manage_users',
      'view_medical_records',
      'edit_medical_records',
      'view_appointments',
      'edit_appointments',
      'view_patient_basic_info',
      'schedule_appointments',
      'manage_system_settings'
    ],
    doctor: [
      'view_medical_records',
      'edit_medical_records',
      'view_appointments',
      'edit_appointments',
      'view_patient_basic_info',
      'schedule_appointments'
    ],
    receptionist: [
      'view_appointments',
      'edit_appointments',
      'view_patient_basic_info',
      'schedule_appointments'
    ],
    guest: []
  };
  
  return permissions[role]?.includes(permission) || false;
}

function getPasswordRequirements() {
  return {
    minLength: 8,
    requireUppercase: true,
    requireLowercase: true,
    requireNumbers: true,
    requireSymbols: true,
    maxAge: 90
  };
}

function isCommonPassword(password) {
  const commonPasswords = [
    'password', 'password123', '12345678', 'qwerty', 'admin', 
    'dental123', 'clinic123', '123456789', 'abc123', 'letmein'
  ];
  
  return commonPasswords.includes(password.toLowerCase());
}

function requestPasswordReset(email) {
  return fetch('/api/v1/auth/password/reset', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
    },
    body: JSON.stringify({ email: email })
  }).then(response => response.json());
}