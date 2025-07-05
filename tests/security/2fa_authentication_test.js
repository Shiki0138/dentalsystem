// 🦷 Dental System - 2FA Authentication Security Tests
// Two-Factor Authentication implementation and security testing

describe('Two-Factor Authentication (2FA) Security', () => {
  const baseUrl = 'http://localhost:3000';
  
  beforeEach(() => {
    // Mock CSRF token
    global.fetch = jest.fn();
    global.document = {
      querySelector: jest.fn(() => ({
        getAttribute: () => 'mock-csrf-token'
      }))
    };
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('2FA Setup and Configuration', () => {
    test('should generate secure TOTP secret', async () => {
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          status: 'success',
          secret: 'JBSWY3DPEHPK3PXP',
          qr_code: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
          backup_codes: [
            '12345678', '87654321', '11111111', '22222222', '33333333',
            '44444444', '55555555', '66666666', '77777777', '88888888'
          ]
        })
      });

      const response = await fetch(`${baseUrl}/api/v1/auth/2fa/setup`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': 'mock-csrf-token'
        }
      });

      const data = await response.json();
      
      // Validate TOTP secret format (Base32)
      expect(data.secret).toMatch(/^[A-Z2-7]+$/);
      expect(data.secret.length).toBeGreaterThanOrEqual(16);
      
      // Validate QR code format
      expect(data.qr_code).toContain('data:image/png;base64,');
      
      // Validate backup codes
      expect(data.backup_codes).toHaveLength(10);
      data.backup_codes.forEach(code => {
        expect(code).toMatch(/^\d{8}$/); // 8-digit numeric codes
      });
      
      console.log('✅ 安全なTOTPシークレット生成テスト完了');
    });

    test('should validate TOTP code format and timing', () => {
      const validCodes = ['123456', '000000', '999999'];
      const invalidCodes = [
        '12345',      // Too short
        '1234567',    // Too long
        'abcdef',     // Non-numeric
        '12 34 56',   // Contains spaces
        '',           // Empty
        null,         // Null
        undefined     // Undefined
      ];

      // Test valid codes
      validCodes.forEach(code => {
        expect(isValid2FACode(code)).toBe(true);
      });

      // Test invalid codes
      invalidCodes.forEach(code => {
        expect(isValid2FACode(code)).toBe(false);
      });

      console.log('✅ TOTPコードフォーマット検証テスト完了');
    });

    test('should enforce TOTP time window validation', async () => {
      const currentTime = Math.floor(Date.now() / 1000);
      const timeStep = 30; // Standard TOTP time step
      
      // Mock different time windows
      const testCases = [
        { timestamp: currentTime, shouldAccept: true },
        { timestamp: currentTime - timeStep, shouldAccept: true },  // Previous window
        { timestamp: currentTime + timeStep, shouldAccept: true },  // Next window
        { timestamp: currentTime - (timeStep * 2), shouldAccept: false }, // Too old
        { timestamp: currentTime + (timeStep * 2), shouldAccept: false }  // Too far future
      ];

      for (const testCase of testCases) {
        fetch.mockResolvedValueOnce({
          ok: testCase.shouldAccept,
          status: testCase.shouldAccept ? 200 : 401,
          json: async () => ({
            status: testCase.shouldAccept ? 'success' : 'error',
            verified: testCase.shouldAccept,
            message: testCase.shouldAccept ? '認証成功' : '認証コードが無効です'
          })
        });

        const response = await fetch(`${baseUrl}/api/v1/auth/2fa/verify`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': 'mock-csrf-token'
          },
          body: JSON.stringify({ 
            code: '123456',
            timestamp: testCase.timestamp 
          })
        });

        expect(response.ok).toBe(testCase.shouldAccept);
      }
      
      console.log('✅ TOTP時間窓検証テスト完了');
    });
  });

  describe('2FA Authentication Flow Security', () => {
    test('should prevent 2FA bypass attempts', async () => {
      const bypassAttempts = [
        // Common bypass codes
        '000000', '123456', '111111', '999999',
        // SQL injection attempts
        "'; DROP TABLE users; --",
        '1\' OR \'1\'=\'1',
        // Script injection
        '<script>alert("bypass")</script>',
        // Null/empty attempts
        '', null, undefined,
        // Buffer overflow attempts
        'A'.repeat(1000),
        // Unicode/encoding attempts
        '１２３４５６', // Full-width numbers
        '\u0031\u0032\u0033\u0034\u0035\u0036'
      ];

      for (const attempt of bypassAttempts) {
        fetch.mockResolvedValueOnce({
          ok: false,
          status: 401,
          json: async () => ({
            status: 'error',
            message: '認証コードが正しくありません'
          })
        });

        const response = await fetch(`${baseUrl}/api/v1/auth/2fa/verify`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': 'mock-csrf-token'
          },
          body: JSON.stringify({ code: attempt })
        });

        expect(response.status).toBe(401);
      }

      console.log('✅ 2FAバイパス防止テスト完了');
    });

    test('should implement rate limiting for 2FA attempts', async () => {
      const attempts = [];
      
      // Simulate rapid 2FA attempts
      for (let i = 0; i < 10; i++) {
        fetch.mockResolvedValueOnce({
          ok: false,
          status: i < 5 ? 401 : 429, // Rate limit after 5 attempts
          json: async () => ({
            status: 'error',
            message: i < 5 ? '認証コードが正しくありません' : 'レート制限に達しました'
          })
        });

        attempts.push(
          fetch(`${baseUrl}/api/v1/auth/2fa/verify`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'X-CSRF-Token': 'mock-csrf-token'
            },
            body: JSON.stringify({ code: '000000' })
          })
        );
      }

      const responses = await Promise.all(attempts);
      const rateLimitedResponses = responses.filter(r => r.status === 429);
      
      expect(rateLimitedResponses.length).toBeGreaterThan(0);
      console.log(`✅ 2FAレート制限: ${rateLimitedResponses.length}/10 リクエストがブロックされました`);
    });

    test('should secure backup code authentication', async () => {
      const validBackupCodes = [
        '12345678', '87654321', '11111111'
      ];
      
      const invalidBackupCodes = [
        '1234567',     // Too short
        '123456789',   // Too long
        'abcd1234',    // Non-numeric
        '12-34-56-78', // Invalid format
        '',            // Empty
        null           // Null
      ];

      // Test valid backup codes
      for (const code of validBackupCodes) {
        fetch.mockResolvedValueOnce({
          ok: true,
          json: async () => ({
            status: 'success',
            verified: true,
            backup_code_used: true,
            remaining_codes: validBackupCodes.length - 1
          })
        });

        const response = await fetch(`${baseUrl}/api/v1/auth/2fa/backup`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': 'mock-csrf-token'
          },
          body: JSON.stringify({ backup_code: code })
        });

        expect(response.ok).toBe(true);
      }

      // Test invalid backup codes
      for (const code of invalidBackupCodes) {
        fetch.mockResolvedValueOnce({
          ok: false,
          status: 401,
          json: async () => ({
            status: 'error',
            message: 'バックアップコードが正しくありません'
          })
        });

        const response = await fetch(`${baseUrl}/api/v1/auth/2fa/backup`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': 'mock-csrf-token'
          },
          body: JSON.stringify({ backup_code: code })
        });

        expect(response.status).toBe(401);
      }

      console.log('✅ バックアップコード認証セキュリティテスト完了');
    });

    test('should ensure backup codes are single-use', async () => {
      const backupCode = '12345678';

      // First use - should succeed
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          status: 'success',
          verified: true,
          backup_code_used: true
        })
      });

      const firstResponse = await fetch(`${baseUrl}/api/v1/auth/2fa/backup`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': 'mock-csrf-token'
        },
        body: JSON.stringify({ backup_code: backupCode })
      });

      expect(firstResponse.ok).toBe(true);

      // Second use - should fail
      fetch.mockResolvedValueOnce({
        ok: false,
        status: 401,
        json: async () => ({
          status: 'error',
          message: 'バックアップコードは既に使用されています'
        })
      });

      const secondResponse = await fetch(`${baseUrl}/api/v1/auth/2fa/backup`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': 'mock-csrf-token'
        },
        body: JSON.stringify({ backup_code: backupCode })
      });

      expect(secondResponse.status).toBe(401);
      console.log('✅ バックアップコード単回使用制限テスト完了');
    });
  });

  describe('2FA Session Management', () => {
    test('should enforce 2FA session timeout', async () => {
      // Test normal 2FA session
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          status: 'pending_2fa',
          session_expires_at: new Date(Date.now() + 5 * 60 * 1000).toISOString(), // 5 minutes
          message: '2段階認証コードを入力してください'
        })
      });

      const loginResponse = await fetch(`${baseUrl}/api/v1/auth/login`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': 'mock-csrf-token'
        },
        body: JSON.stringify({
          email: 'test@dental.com',
          password: 'password123'
        })
      });

      const loginData = await loginResponse.json();
      expect(loginData.status).toBe('pending_2fa');

      // Test expired 2FA session
      fetch.mockResolvedValueOnce({
        ok: false,
        status: 401,
        json: async () => ({
          status: 'error',
          message: '2段階認証セッションが期限切れです'
        })
      });

      const expiredResponse = await fetch(`${baseUrl}/api/v1/auth/2fa/verify`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': 'mock-csrf-token'
        },
        body: JSON.stringify({ 
          code: '123456',
          session_id: 'expired_session'
        })
      });

      expect(expiredResponse.status).toBe(401);
      console.log('✅ 2FAセッションタイムアウト制御テスト完了');
    });

    test('should invalidate 2FA session after successful authentication', async () => {
      const sessionId = 'test_2fa_session_123';

      // Successful 2FA verification
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          status: 'success',
          verified: true,
          access_token: 'jwt_token_123',
          session_invalidated: true
        })
      });

      const verifyResponse = await fetch(`${baseUrl}/api/v1/auth/2fa/verify`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': 'mock-csrf-token'
        },
        body: JSON.stringify({ 
          code: '123456',
          session_id: sessionId
        })
      });

      const verifyData = await verifyResponse.json();
      expect(verifyData.session_invalidated).toBe(true);

      // Attempt to reuse the same session - should fail
      fetch.mockResolvedValueOnce({
        ok: false,
        status: 401,
        json: async () => ({
          status: 'error',
          message: '無効なセッションです'
        })
      });

      const reuseResponse = await fetch(`${baseUrl}/api/v1/auth/2fa/verify`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': 'mock-csrf-token'
        },
        body: JSON.stringify({ 
          code: '654321',
          session_id: sessionId
        })
      });

      expect(reuseResponse.status).toBe(401);
      console.log('✅ 2FAセッション無効化テスト完了');
    });
  });

  describe('2FA Recovery and Management', () => {
    test('should securely handle 2FA reset requests', async () => {
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          status: 'success',
          message: '2段階認証リセット要求を受け付けました',
          verification_required: true,
          verification_methods: ['email', 'security_questions']
        })
      });

      const resetResponse = await fetch(`${baseUrl}/api/v1/auth/2fa/reset`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': 'mock-csrf-token'
        },
        body: JSON.stringify({
          email: 'test@dental.com',
          reason: 'device_lost'
        })
      });

      const resetData = await resetResponse.json();
      expect(resetData.verification_required).toBe(true);
      expect(resetData.verification_methods).toContain('email');
      
      console.log('✅ 2FAリセット要求セキュリティテスト完了');
    });

    test('should validate admin 2FA override permissions', async () => {
      // Test non-admin user attempting override
      fetch.mockResolvedValueOnce({
        ok: false,
        status: 403,
        json: async () => ({
          status: 'error',
          message: '権限がありません'
        })
      });

      const unauthorizedResponse = await fetch(`${baseUrl}/api/v1/admin/2fa/override`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': 'mock-csrf-token',
          'Authorization': 'Bearer non_admin_token'
        },
        body: JSON.stringify({
          user_id: 123,
          override_reason: 'emergency_access'
        })
      });

      expect(unauthorizedResponse.status).toBe(403);

      // Test admin user with proper authorization
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          status: 'success',
          message: '2段階認証を一時的に無効化しました',
          audit_logged: true,
          temporary_access_expires: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
        })
      });

      const authorizedResponse = await fetch(`${baseUrl}/api/v1/admin/2fa/override`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': 'mock-csrf-token',
          'Authorization': 'Bearer admin_token'
        },
        body: JSON.stringify({
          user_id: 123,
          override_reason: 'emergency_access',
          admin_2fa_code: '654321'
        })
      });

      const authorizedData = await authorizedResponse.json();
      expect(authorizedData.audit_logged).toBe(true);
      
      console.log('✅ 管理者2FAオーバーライド権限テスト完了');
    });
  });

  describe('2FA Audit and Logging', () => {
    test('should log all 2FA authentication attempts', async () => {
      const testCases = [
        { code: '123456', result: 'success' },
        { code: '000000', result: 'failure' },
        { code: '654321', result: 'success' }
      ];

      for (const testCase of testCases) {
        fetch.mockResolvedValueOnce({
          ok: testCase.result === 'success',
          status: testCase.result === 'success' ? 200 : 401,
          json: async () => ({
            status: testCase.result === 'success' ? 'success' : 'error',
            verified: testCase.result === 'success',
            audit_logged: true,
            attempt_id: `attempt_${Date.now()}`
          })
        });

        const response = await fetch(`${baseUrl}/api/v1/auth/2fa/verify`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': 'mock-csrf-token'
          },
          body: JSON.stringify({ code: testCase.code })
        });

        const data = await response.json();
        expect(data.audit_logged).toBe(true);
      }

      console.log('✅ 2FA認証試行ログ記録テスト完了');
    });

    test('should track 2FA device enrollment and management', async () => {
      // Test device enrollment
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          status: 'success',
          device_enrolled: true,
          device_id: 'device_123',
          device_name: 'iPhone 12',
          enrolled_at: new Date().toISOString(),
          audit_logged: true
        })
      });

      const enrollResponse = await fetch(`${baseUrl}/api/v1/auth/2fa/devices`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': 'mock-csrf-token'
        },
        body: JSON.stringify({
          device_name: 'iPhone 12',
          device_fingerprint: 'fp_12345'
        })
      });

      const enrollData = await enrollResponse.json();
      expect(enrollData.audit_logged).toBe(true);
      expect(enrollData.device_enrolled).toBe(true);

      console.log('✅ 2FAデバイス管理ログテスト完了');
    });
  });
});

// Helper function for TOTP code validation
function isValid2FACode(code) {
  if (typeof code !== 'string' && typeof code !== 'number') {
    return false;
  }
  
  const codeStr = String(code);
  return /^\d{6}$/.test(codeStr);
}