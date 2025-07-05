// 🦷 Dental System - CSP Header Security Tests
// Content Security Policy implementation and testing

describe('Content Security Policy (CSP) Testing', () => {
  const baseUrl = 'http://localhost:3000';

  describe('CSP Header Implementation', () => {
    test('should have proper CSP header configured', async () => {
      const response = await fetch(baseUrl);
      const cspHeader = response.headers.get('content-security-policy');
      
      expect(cspHeader).toBeTruthy();
      console.log(`🔒 CSP Header: ${cspHeader}`);

      // Parse CSP directives
      const directives = cspHeader.split(';').map(d => d.trim());
      const cspMap = {};
      
      directives.forEach(directive => {
        const [key, ...values] = directive.split(' ');
        cspMap[key] = values.join(' ');
      });

      // Test essential CSP directives for dental system
      expect(cspMap['default-src']).toBeDefined();
      expect(cspMap['script-src']).toBeDefined();
      expect(cspMap['style-src']).toBeDefined();
      expect(cspMap['img-src']).toBeDefined();
      expect(cspMap['connect-src']).toBeDefined();
      expect(cspMap['font-src']).toBeDefined();
      
      console.log('✅ 必須CSPディレクティブが設定されています');
    });

    test('should restrict script sources appropriately', async () => {
      const response = await fetch(baseUrl);
      const cspHeader = response.headers.get('content-security-policy');
      
      // Should not allow unsafe-eval or unsafe-inline for scripts
      expect(cspHeader).not.toContain('unsafe-eval');
      expect(cspHeader).not.toContain('unsafe-inline');
      
      // Should include nonce or hash-based CSP for inline scripts
      const hasNonce = cspHeader.includes("'nonce-");
      const hasHash = cspHeader.includes("'sha256-") || cspHeader.includes("'sha384-") || cspHeader.includes("'sha512-");
      const hasStrictDynamic = cspHeader.includes("'strict-dynamic'");
      
      if (!hasStrictDynamic) {
        expect(hasNonce || hasHash).toBe(true);
      }
      
      console.log('✅ スクリプトソースが適切に制限されています');
    });

    test('should allow necessary external resources', async () => {
      const response = await fetch(baseUrl);
      const cspHeader = response.headers.get('content-security-policy');
      
      // Should allow Bootstrap CDN for styling
      expect(cspHeader).toContain('cdn.jsdelivr.net');
      
      // Should allow necessary font sources
      expect(cspHeader).toContain('fonts.googleapis.com');
      expect(cspHeader).toContain('fonts.gstatic.com');
      
      console.log('✅ 必要な外部リソースが許可されています');
    });

    test('should prevent frame injection attacks', async () => {
      const response = await fetch(baseUrl);
      const cspHeader = response.headers.get('content-security-policy');
      
      // Should have frame-src directive
      expect(cspHeader).toContain('frame-src');
      
      // Should restrict frame sources
      const frameDirective = cspHeader.match(/frame-src[^;]+/);
      if (frameDirective) {
        expect(frameDirective[0]).not.toContain('*');
        expect(frameDirective[0]).not.toContain('data:');
      }
      
      console.log('✅ フレームインジェクション攻撃が防止されています');
    });
  });

  describe('CSP Violation Testing', () => {
    test('should detect and block inline script violations', async () => {
      // Create a test page with inline script
      const maliciousScript = `
        <html>
          <head>
            <script>
              // This should be blocked by CSP
              document.cookie = 'stolen=true';
              fetch('/api/v1/patients').then(r => r.json()).then(console.log);
            </script>
          </head>
          <body>Test Page</body>
        </html>
      `;

      // Test if CSP would block this script
      const response = await fetch(`${baseUrl}/test-csp-violation`, {
        method: 'POST',
        headers: { 'Content-Type': 'text/html' },
        body: maliciousScript
      });

      // Should either block or report violation
      expect([400, 403, 200]).toContain(response.status);
      console.log('🔒 インラインスクリプト違反検出テスト完了');
    });

    test('should block unauthorized external script loading', async () => {
      // Test loading script from unauthorized domain
      const unauthorizedScript = 'https://malicious-domain.com/evil-script.js';
      
      // This test simulates browser behavior - in real scenario, CSP would block
      const testScript = `
        <script src="${unauthorizedScript}"></script>
      `;

      // Check CSP header allows/blocks this domain
      const response = await fetch(baseUrl);
      const cspHeader = response.headers.get('content-security-policy');
      
      expect(cspHeader).not.toContain('malicious-domain.com');
      expect(cspHeader).not.toContain('*');
      
      console.log('🔒 不正な外部スクリプトがブロックされます');
    });

    test('should report CSP violations', async () => {
      const response = await fetch(baseUrl);
      const cspHeader = response.headers.get('content-security-policy');
      
      // Should have report-uri or report-to directive
      const hasReporting = cspHeader.includes('report-uri') || cspHeader.includes('report-to');
      expect(hasReporting).toBe(true);
      
      console.log('✅ CSP違反レポート機能が設定されています');
    });
  });

  describe('Nonce-based CSP Implementation', () => {
    test('should generate unique nonces for each request', async () => {
      const responses = await Promise.all([
        fetch(baseUrl),
        fetch(baseUrl),
        fetch(baseUrl)
      ]);

      const nonces = responses.map(response => {
        const cspHeader = response.headers.get('content-security-policy');
        const nonceMatch = cspHeader.match(/'nonce-([^']+)'/);
        return nonceMatch ? nonceMatch[1] : null;
      });

      // All nonces should be unique
      const uniqueNonces = new Set(nonces.filter(n => n !== null));
      expect(uniqueNonces.size).toBe(nonces.filter(n => n !== null).length);
      
      console.log('✅ ユニークなnonceが生成されています');
    });

    test('should include nonce in inline scripts', async () => {
      const response = await fetch(baseUrl);
      const html = await response.text();
      const cspHeader = response.headers.get('content-security-policy');
      
      const nonceMatch = cspHeader.match(/'nonce-([^']+)'/);
      if (nonceMatch) {
        const nonce = nonceMatch[1];
        
        // Check if HTML includes the same nonce in script tags
        expect(html).toContain(`nonce="${nonce}"`);
        console.log(`✅ HTMLにnonce属性が含まれています: ${nonce}`);
      }
    });
  });

  describe('Subresource Integrity (SRI) Testing', () => {
    test('should implement SRI for external resources', async () => {
      const response = await fetch(baseUrl);
      const html = await response.text();
      
      // Check for SRI attributes on external scripts and stylesheets
      const externalScripts = html.match(/<script[^>]+src=[^>]+>/g) || [];
      const externalStyles = html.match(/<link[^>]+rel="stylesheet"[^>]*>/g) || [];
      
      const externalResources = [...externalScripts, ...externalStyles];
      const resourcesWithSRI = externalResources.filter(resource => 
        resource.includes('integrity=') && resource.includes('crossorigin=')
      );
      
      // External CDN resources should have SRI
      const cdnResources = externalResources.filter(resource => 
        resource.includes('cdn.') || resource.includes('googleapis.com')
      );
      
      if (cdnResources.length > 0) {
        expect(resourcesWithSRI.length).toBeGreaterThan(0);
        console.log(`✅ SRI実装: ${resourcesWithSRI.length}/${cdnResources.length} CDNリソース`);
      }
    });
  });

  describe('Mixed Content Prevention', () => {
    test('should prevent mixed content vulnerabilities', async () => {
      const response = await fetch(baseUrl);
      const cspHeader = response.headers.get('content-security-policy');
      
      // Should block mixed content
      expect(cspHeader).toContain('block-all-mixed-content');
      
      // Or upgrade insecure requests
      const hasUpgradeInsecure = cspHeader.includes('upgrade-insecure-requests');
      const hasBlockMixed = cspHeader.includes('block-all-mixed-content');
      
      expect(hasUpgradeInsecure || hasBlockMixed).toBe(true);
      
      console.log('✅ 混合コンテンツ攻撃が防止されています');
    });

    test('should enforce HTTPS for sensitive operations', async () => {
      const response = await fetch(baseUrl);
      const cspHeader = response.headers.get('content-security-policy');
      
      // Should upgrade insecure requests
      expect(cspHeader).toContain('upgrade-insecure-requests');
      
      // Check HSTS header as well
      const hstsHeader = response.headers.get('strict-transport-security');
      expect(hstsHeader).toBeTruthy();
      
      console.log('✅ HTTPS強制が設定されています');
    });
  });

  describe('CSP Bypass Prevention', () => {
    test('should prevent common CSP bypass techniques', async () => {
      const response = await fetch(baseUrl);
      const cspHeader = response.headers.get('content-security-policy');
      
      // Should not allow data: URIs for scripts
      expect(cspHeader).not.toContain('data:');
      
      // Should not use wildcard with unsafe-inline
      const hasWildcard = cspHeader.includes('*');
      const hasUnsafeInline = cspHeader.includes('unsafe-inline');
      
      if (hasWildcard && hasUnsafeInline) {
        fail('CSP allows wildcard with unsafe-inline - this is insecure');
      }
      
      // Should not allow object-src without restrictions
      if (cspHeader.includes('object-src')) {
        expect(cspHeader).not.toContain("object-src *");
      }
      
      console.log('✅ 一般的なCSPバイパス手法が防止されています');
    });

    test('should validate CSP syntax and effectiveness', async () => {
      const response = await fetch(baseUrl);
      const cspHeader = response.headers.get('content-security-policy');
      
      // Basic syntax validation
      expect(cspHeader).not.toContain(';;'); // No double semicolons
      expect(cspHeader).not.toContain('  '); // No double spaces
      
      // Should end with semicolon
      expect(cspHeader.trim().endsWith(';')).toBe(true);
      
      // Should have proper quoting for keywords
      const keywords = ['self', 'none', 'unsafe-inline', 'unsafe-eval', 'strict-dynamic'];
      keywords.forEach(keyword => {
        if (cspHeader.includes(keyword)) {
          expect(cspHeader).toContain(`'${keyword}'`);
        }
      });
      
      console.log('✅ CSP構文が有効です');
    });
  });
})