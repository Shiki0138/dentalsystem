// 🦷 Dental System - OWASP ZAP Security Tests
// Automated security testing with OWASP ZAP

const ZapClient = require('zaproxy');

describe('OWASP ZAP Security Testing', () => {
  let zapClient;
  const baseUrl = 'http://localhost:3000';
  const zapOptions = {
    host: 'localhost',
    port: 8080
  };

  beforeAll(async () => {
    zapClient = new ZapClient({
      proxy: `http://${zapOptions.host}:${zapOptions.port}`
    });
    
    // Start ZAP session
    await zapClient.core.newSession('dental-system-security-test');
    console.log('🔒 OWASP ZAP セキュリティテストセッション開始');
  });

  afterAll(async () => {
    // Generate security report
    const htmlReport = await zapClient.core.htmlReport();
    const jsonReport = await zapClient.core.jsonReport();
    
    // Save reports
    require('fs').writeFileSync('tests/security/reports/zap-report.html', htmlReport);
    require('fs').writeFileSync('tests/security/reports/zap-report.json', jsonReport);
    
    console.log('🔒 セキュリティレポート生成完了');
  });

  describe('Spider and Discovery', () => {
    test('should perform automated spider crawling', async () => {
      console.log('🕷️ スパイダークロール開始...');
      
      // Start spider
      const spiderScanId = await zapClient.spider.scan(baseUrl);
      
      // Wait for spider to complete
      let progress = 0;
      while (progress < 100) {
        await new Promise(resolve => setTimeout(resolve, 2000));
        const status = await zapClient.spider.status(spiderScanId);
        progress = parseInt(status);
        console.log(`スパイダー進行状況: ${progress}%`);
      }
      
      // Get spider results
      const spiderResults = await zapClient.spider.results(spiderScanId);
      expect(spiderResults.length).toBeGreaterThan(0);
      
      console.log(`🕷️ スパイダークロール完了: ${spiderResults.length}ページ発見`);
    }, 300000); // 5 minutes timeout

    test('should discover all major application endpoints', async () => {
      const siteTree = await zapClient.core.urls(baseUrl);
      
      // Check for critical endpoints
      const criticalEndpoints = [
        '/users/sign_in',
        '/users/sign_up', 
        '/api/v1/patients',
        '/api/v1/appointments',
        '/api/v1/auth/login',
        '/api/v1/auth/2fa/verify'
      ];
      
      criticalEndpoints.forEach(endpoint => {
        const found = siteTree.some(url => url.includes(endpoint));
        expect(found).toBe(true);
        console.log(`✅ エンドポイント発見: ${endpoint}`);
      });
    });
  });

  describe('Active Security Scanning', () => {
    test('should perform comprehensive active scan', async () => {
      console.log('🔍 アクティブセキュリティスキャン開始...');
      
      // Configure scan policy for dental system
      const scanPolicy = {
        'SQL Injection': true,
        'XSS (Cross Site Scripting)': true,
        'Cross Site Request Forgery': true,
        'Directory Browsing': true,
        'Path Traversal': true,
        'Remote File Inclusion': true,
        'Server Side Include': true,
        'Script Active Scan Rules': true,
        'Server Side Code Injection': true,
        'External Redirect': true,
        'CRLF Injection': true,
        'Parameter Pollution': true,
        'Generic Padding Oracle': true,
        'Expression Language Injection': true,
        'LDAP Injection': true,
        'NoSQL Injection': true,
        'XPath Injection': true,
        'XML External Entity Attack': true,
        'Remote Code Execution': true
      };
      
      // Start active scan
      const activeScanId = await zapClient.ascan.scan({
        url: baseUrl,
        recurse: true,
        inScopeOnly: false,
        scanPolicyName: 'dental-system-policy'
      });
      
      // Monitor scan progress
      let progress = 0;
      while (progress < 100) {
        await new Promise(resolve => setTimeout(resolve, 5000));
        const status = await zapClient.ascan.status(activeScanId);
        progress = parseInt(status);
        console.log(`アクティブスキャン進行状況: ${progress}%`);
      }
      
      console.log('🔍 アクティブセキュリティスキャン完了');
    }, 600000); // 10 minutes timeout

    test('should check for SQL injection vulnerabilities', async () => {
      const alerts = await zapClient.core.alerts(baseUrl);
      
      const sqlInjectionAlerts = alerts.filter(alert => 
        alert.alert.toLowerCase().includes('sql injection') ||
        alert.cweid === '89' ||
        alert.wascid === '19'
      );
      
      console.log(`🔍 SQLインジェクション検査: ${sqlInjectionAlerts.length}件の警告`);
      
      // Log any SQL injection findings
      sqlInjectionAlerts.forEach(alert => {
        console.log(`⚠️ SQLインジェクション警告: ${alert.alert} - ${alert.url}`);
        expect(alert.risk).not.toBe('High'); // Should not have high-risk SQL injection
      });
    });

    test('should check for XSS vulnerabilities', async () => {
      const alerts = await zapClient.core.alerts(baseUrl);
      
      const xssAlerts = alerts.filter(alert => 
        alert.alert.toLowerCase().includes('cross site scripting') ||
        alert.alert.toLowerCase().includes('xss') ||
        alert.cweid === '79'
      );
      
      console.log(`🔍 XSS検査: ${xssAlerts.length}件の警告`);
      
      xssAlerts.forEach(alert => {
        console.log(`⚠️ XSS警告: ${alert.alert} - ${alert.url}`);
        expect(alert.risk).not.toBe('High'); // Should not have high-risk XSS
      });
    });

    test('should check for CSRF vulnerabilities', async () => {
      const alerts = await zapClient.core.alerts(baseUrl);
      
      const csrfAlerts = alerts.filter(alert => 
        alert.alert.toLowerCase().includes('csrf') ||
        alert.alert.toLowerCase().includes('cross site request forgery') ||
        alert.cweid === '352'
      );
      
      console.log(`🔍 CSRF検査: ${csrfAlerts.length}件の警告`);
      
      csrfAlerts.forEach(alert => {
        console.log(`⚠️ CSRF警告: ${alert.alert} - ${alert.url}`);
        // CSRF protection should be in place for state-changing operations
      });
    });
  });

  describe('Authentication Security Testing', () => {
    test('should test authentication bypass attempts', async () => {
      const authEndpoints = [
        '/api/v1/patients',
        '/api/v1/appointments', 
        '/dashboard',
        '/admin'
      ];
      
      for (const endpoint of authEndpoints) {
        // Try to access without authentication
        const response = await fetch(`${baseUrl}${endpoint}`, {
          method: 'GET',
          headers: {
            'User-Agent': 'OWASP-ZAP-Security-Test'
          }
        });
        
        // Should be redirected to login or return 401/403
        expect([401, 403, 302]).toContain(response.status);
        console.log(`🔒 認証チェック OK: ${endpoint} - ${response.status}`);
      }
    });

    test('should test session management security', async () => {
      // Test session fixation
      const loginEndpoint = `${baseUrl}/api/v1/auth/login`;
      
      // Test with manipulated session
      const response = await fetch(loginEndpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'session_id=manipulated_session_12345'
        },
        body: JSON.stringify({
          email: 'test@example.com',
          password: 'wrongpassword'
        })
      });
      
      expect(response.status).toBe(401);
      console.log('🔒 セッション操作テスト OK');
    });

    test('should test 2FA bypass attempts', async () => {
      const twoFAEndpoint = `${baseUrl}/api/v1/auth/2fa/verify`;
      
      // Test various bypass attempts
      const bypassAttempts = [
        '000000',
        '123456',
        'null',
        '',
        '999999',
        '000001',
        'admin'
      ];
      
      for (const code of bypassAttempts) {
        const response = await fetch(twoFAEndpoint, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({ code })
        });
        
        // Should reject invalid codes
        expect([400, 401, 422]).toContain(response.status);
      }
      
      console.log('🔒 2FA バイパス防止テスト OK');
    });
  });

  describe('Input Validation Security', () => {
    test('should test malicious input handling', async () => {
      const maliciousInputs = [
        // SQL Injection payloads
        "'; DROP TABLE patients; --",
        "1' OR '1'='1",
        "admin'/*",
        "' UNION SELECT * FROM users --",
        
        // XSS payloads
        '<script>alert("XSS")</script>',
        'javascript:alert("XSS")',
        '<img src=x onerror=alert("XSS")>',
        '"><script>alert("XSS")</script>',
        
        // Path traversal
        '../../../etc/passwd',
        '..\\..\\..\\windows\\system32\\config\\sam',
        
        // Command injection
        '; cat /etc/passwd',
        '| whoami',
        '&& dir',
        
        // LDAP injection
        '*)(cn=*',
        '*)(&(objectclass=*',
        
        // NoSQL injection
        '{"$gt":""}',
        '{"$ne":null}',
        
        // XML/XXE
        '<?xml version="1.0"?><!DOCTYPE root [<!ENTITY test SYSTEM "file:///etc/passwd">]><root>&test;</root>'
      ];
      
      const testEndpoints = [
        '/api/v1/patients/search',
        '/api/v1/appointments/search',
        '/api/v1/patients',
        '/api/v1/appointments'
      ];
      
      for (const endpoint of testEndpoints) {
        for (const payload of maliciousInputs) {
          const response = await fetch(`${baseUrl}${endpoint}?q=${encodeURIComponent(payload)}`, {
            headers: {
              'User-Agent': 'OWASP-ZAP-Security-Test'
            }
          });
          
          // Should not return 500 errors (proper error handling)
          expect(response.status).not.toBe(500);
          
          // Response should not contain the raw payload (proper sanitization)
          const responseText = await response.text();
          expect(responseText).not.toContain(payload);
        }
      }
      
      console.log('🔒 悪意のある入力処理テスト OK');
    });
  });

  describe('Security Headers Testing', () => {
    test('should verify security headers are present', async () => {
      const response = await fetch(baseUrl);
      const headers = response.headers;
      
      // Check for essential security headers
      const securityHeaders = {
        'x-frame-options': 'DENY または SAMEORIGIN',
        'x-content-type-options': 'nosniff',
        'x-xss-protection': '1; mode=block',
        'strict-transport-security': 'max-age設定',
        'content-security-policy': 'CSP設定',
        'referrer-policy': 'strict-origin-when-cross-origin'
      };
      
      Object.keys(securityHeaders).forEach(header => {
        expect(headers.has(header)).toBe(true);
        console.log(`✅ セキュリティヘッダー確認: ${header} = ${headers.get(header)}`);
      });
    });
  });

  describe('API Security Testing', () => {
    test('should test API rate limiting', async () => {
      const apiEndpoint = `${baseUrl}/api/v1/auth/login`;
      const requests = [];
      
      // Send multiple rapid requests
      for (let i = 0; i < 20; i++) {
        requests.push(
          fetch(apiEndpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email: 'test@test.com', password: 'test' })
          })
        );
      }
      
      const responses = await Promise.all(requests);
      const rateLimitedResponses = responses.filter(r => r.status === 429);
      
      // Should have rate limiting in place
      expect(rateLimitedResponses.length).toBeGreaterThan(0);
      console.log(`🔒 レート制限テスト: ${rateLimitedResponses.length}/20 がブロックされました`);
    });

    test('should test API authentication requirements', async () => {
      const protectedEndpoints = [
        '/api/v1/patients',
        '/api/v1/appointments',
        '/api/v1/users/profile',
        '/api/v1/admin/settings'
      ];
      
      for (const endpoint of protectedEndpoints) {
        const response = await fetch(`${baseUrl}${endpoint}`);
        expect([401, 403]).toContain(response.status);
        console.log(`🔒 API認証要件テスト OK: ${endpoint}`);
      }
    });
  });

  describe('File Upload Security', () => {
    test('should test malicious file upload prevention', async () => {
      const maliciousFiles = [
        { name: 'test.php', content: '<?php system($_GET["cmd"]); ?>', type: 'application/x-php' },
        { name: 'test.jsp', content: '<% Runtime.getRuntime().exec(request.getParameter("cmd")); %>', type: 'application/x-jsp' },
        { name: 'test.asp', content: '<% eval request("cmd") %>', type: 'application/x-asp' },
        { name: 'test.exe', content: 'MZ...', type: 'application/x-executable' },
        { name: 'test.svg', content: '<svg><script>alert("XSS")</script></svg>', type: 'image/svg+xml' }
      ];
      
      const uploadEndpoint = `${baseUrl}/api/v1/files/upload`;
      
      for (const file of maliciousFiles) {
        const formData = new FormData();
        formData.append('file', new Blob([file.content], { type: file.type }), file.name);
        
        const response = await fetch(uploadEndpoint, {
          method: 'POST',
          body: formData
        });
        
        // Should reject malicious files
        expect([400, 403, 415]).toContain(response.status);
        console.log(`🔒 悪意のあるファイルアップロード防止: ${file.name} - ${response.status}`);
      }
    });
  });
})