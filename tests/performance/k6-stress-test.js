// 🦷 Dental System - k6 Stress Test
// Stress testing to find system breaking points

import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Rate, Trend, Counter, Gauge } from 'k6/metrics';

// Custom metrics for stress testing
export const errorRate = new Rate('stress_errors');
export const responseTime = new Trend('stress_response_time');
export const concurrentUsers = new Gauge('concurrent_users');
export const failedRequests = new Counter('failed_requests');
export const successfulRequests = new Counter('successful_requests');

// Stress test configuration
export let options = {
  stages: [
    // Gradual ramp-up to identify breaking point
    { duration: '1m', target: 50 },    // Start with moderate load
    { duration: '2m', target: 100 },   // Normal peak load
    { duration: '2m', target: 150 },   // Above normal capacity
    { duration: '3m', target: 200 },   // High stress
    { duration: '3m', target: 300 },   // Very high stress
    { duration: '3m', target: 500 },   // Extreme stress - find breaking point
    { duration: '2m', target: 300 },   // Scale down to observe recovery
    { duration: '2m', target: 100 },   // Return to normal
    { duration: '1m', target: 0 },     // Complete shutdown
  ],
  
  // Stress test thresholds (more lenient than load test)
  thresholds: {
    // Allow higher response times under stress
    'http_req_duration{p(95)}': ['p(95)<5000'],
    'http_req_duration{p(99)}': ['p(99)<10000'],
    
    // Error rate should still be manageable
    'http_req_failed': ['rate<0.1'], // Allow up to 10% failures under extreme stress
    
    // System should handle at least 80% of requests successfully
    'checks': ['rate>0.8'],
    
    // Custom stress metrics
    'stress_errors': ['rate<0.15'],
    'stress_response_time': ['p(95)<8000'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';
const API_URL = `${BASE_URL}/api/v1`;

// Stress test scenarios with different user behaviors
const stressScenarios = [
  'heavy_read_operations',
  'heavy_write_operations', 
  'mixed_operations',
  'database_intensive',
  'concurrent_searches'
];

function getStressScenario() {
  return stressScenarios[Math.floor(Math.random() * stressScenarios.length)];
}

function authenticateStressUser() {
  const response = http.get(`${BASE_URL}/users/sign_in`);
  const csrfMatch = response.body.match(/name="csrf-token" content="([^"]+)"/);
  const csrfToken = csrfMatch ? csrfMatch[1] : null;
  
  const loginResponse = http.post(`${API_URL}/auth/login`, JSON.stringify({
    email: 'stress.test@dental.com',
    password: 'StressTest123!'
  }), {
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': csrfToken,
    },
    tags: { test_type: 'stress_auth' }
  });

  if (loginResponse.status === 200) {
    const loginData = JSON.parse(loginResponse.body);
    return {
      token: loginData.token,
      csrfToken: csrfToken
    };
  }
  
  return null;
}

export default function() {
  concurrentUsers.add(1);
  const scenario = getStressScenario();
  
  group(`Stress Test - ${scenario}`, function() {
    const auth = authenticateStressUser();
    
    if (!auth) {
      errorRate.add(1);
      failedRequests.add(1);
      return;
    }

    const headers = {
      'Authorization': `Bearer ${auth.token}`,
      'Content-Type': 'application/json',
      'X-CSRF-Token': auth.csrfToken,
    };

    switch (scenario) {
      case 'heavy_read_operations':
        executeHeavyReadOperations(headers);
        break;
      case 'heavy_write_operations':
        executeHeavyWriteOperations(headers);
        break;
      case 'mixed_operations':
        executeMixedOperations(headers);
        break;
      case 'database_intensive':
        executeDatabaseIntensiveOperations(headers);
        break;
      case 'concurrent_searches':
        executeConcurrentSearches(headers);
        break;
    }
  });

  // Minimal sleep under stress
  sleep(Math.random() * 0.5 + 0.1); // 0.1-0.6 seconds
}

function executeHeavyReadOperations(headers) {
  group('Heavy Read Operations', function() {
    const operations = [
      () => http.get(`${API_URL}/patients`, { headers, tags: { operation: 'read_patients' } }),
      () => http.get(`${API_URL}/appointments`, { headers, tags: { operation: 'read_appointments' } }),
      () => http.get(`${API_URL}/patients/search?q=田中`, { headers, tags: { operation: 'search_patients' } }),
      () => http.get(`${API_URL}/appointments/today`, { headers, tags: { operation: 'today_appointments' } }),
      () => http.get(`${BASE_URL}/dashboard`, { headers, tags: { operation: 'dashboard' } }),
      () => http.get(`${BASE_URL}/calendar`, { headers, tags: { operation: 'calendar' } }),
    ];

    // Execute multiple read operations rapidly
    for (let i = 0; i < 10; i++) {
      const operation = operations[Math.floor(Math.random() * operations.length)];
      const response = operation();
      
      const success = check(response, {
        'heavy read success': (r) => r.status === 200,
        'heavy read response time acceptable': (r) => r.timings.duration < 10000,
      });

      responseTime.add(response.timings.duration);
      
      if (success) {
        successfulRequests.add(1);
      } else {
        errorRate.add(1);
        failedRequests.add(1);
      }
      
      sleep(0.1); // Very short delay between operations
    }
  });
}

function executeHeavyWriteOperations(headers) {
  group('Heavy Write Operations', function() {
    // Create multiple patients rapidly
    for (let i = 0; i < 5; i++) {
      const patientData = {
        name: `ストレステスト患者_${Date.now()}_${i}`,
        phone: `090-${Math.floor(Math.random() * 10000)}-${Math.floor(Math.random() * 10000)}`,
        email: `stress.${Date.now()}.${i}@test.com`,
        birth_date: '1990-01-01'
      };

      const response = http.post(`${API_URL}/patients`, JSON.stringify({
        patient: patientData
      }), {
        headers,
        tags: { operation: 'create_patient' }
      });

      const success = check(response, {
        'heavy write success': (r) => r.status === 201 || r.status === 200,
        'heavy write response time acceptable': (r) => r.timings.duration < 15000,
      });

      responseTime.add(response.timings.duration);
      
      if (success) {
        successfulRequests.add(1);
      } else {
        errorRate.add(1);
        failedRequests.add(1);
      }
    }

    // Create multiple appointments
    for (let i = 0; i < 3; i++) {
      const appointmentData = {
        patient_id: 1,
        appointment_date: new Date().toISOString().split('T')[0],
        appointment_time: `${10 + i}:00`,
        treatment_type: '定期検診',
        notes: `ストレステスト予約_${Date.now()}_${i}`
      };

      const response = http.post(`${API_URL}/appointments`, JSON.stringify({
        appointment: appointmentData
      }), {
        headers,
        tags: { operation: 'create_appointment' }
      });

      const success = check(response, {
        'appointment creation under stress': (r) => r.status === 201 || r.status === 200,
      });

      if (success) {
        successfulRequests.add(1);
      } else {
        errorRate.add(1);
        failedRequests.add(1);
      }
    }
  });
}

function executeMixedOperations(headers) {
  group('Mixed Operations', function() {
    // Random mix of read and write operations
    const operations = [
      { type: 'read', weight: 7 },   // 70% reads
      { type: 'write', weight: 3 }   // 30% writes
    ];

    for (let i = 0; i < 8; i++) {
      const random = Math.random() * 10;
      
      if (random < 7) {
        // Read operation
        const readOps = [
          () => http.get(`${API_URL}/patients`, { headers }),
          () => http.get(`${API_URL}/appointments`, { headers }),
          () => http.get(`${API_URL}/patients/search?q=テスト`, { headers }),
        ];
        
        const response = readOps[Math.floor(Math.random() * readOps.length)]();
        trackResponse(response, 'mixed_read');
      } else {
        // Write operation
        const patientData = {
          name: `混合テスト_${Date.now()}_${i}`,
          phone: `080-${Math.floor(Math.random() * 10000)}-${Math.floor(Math.random() * 10000)}`,
          email: `mixed.${Date.now()}.${i}@test.com`
        };

        const response = http.post(`${API_URL}/patients`, JSON.stringify({
          patient: patientData
        }), { headers });
        
        trackResponse(response, 'mixed_write');
      }
      
      sleep(0.05); // Very short delay
    }
  });
}

function executeDatabaseIntensiveOperations(headers) {
  group('Database Intensive Operations', function() {
    // Complex queries that stress the database
    const complexQueries = [
      `${API_URL}/patients/search?q=田&age_min=20&age_max=60&sort=created_at`,
      `${API_URL}/appointments?start_date=2025-01-01&end_date=2025-12-31&status=all`,
      `${API_URL}/reports/patients?group_by=age&include_stats=true`,
      `${API_URL}/reports/appointments?group_by=treatment_type&period=yearly`,
      `${API_URL}/dashboard/metrics?period=6months&detailed=true`,
    ];

    complexQueries.forEach((url, index) => {
      const response = http.get(url, {
        headers,
        tags: { operation: `complex_query_${index}` }
      });
      
      const success = check(response, {
        'complex query completes': (r) => r.status === 200,
        'complex query within time limit': (r) => r.timings.duration < 20000, // 20s limit for complex queries
      });

      responseTime.add(response.timings.duration);
      
      if (success) {
        successfulRequests.add(1);
      } else {
        errorRate.add(1);
        failedRequests.add(1);
      }
      
      sleep(0.2); // Brief pause between complex queries
    });
  });
}

function executeConcurrentSearches(headers) {
  group('Concurrent Searches', function() {
    const searchTerms = ['田中', '佐藤', '山田', '高橋', '小林', 'テスト', '検診', '治療'];
    
    // Execute multiple searches concurrently
    const searchRequests = searchTerms.map(term => [
      'GET',
      `${API_URL}/patients/search?q=${encodeURIComponent(term)}`,
      null,
      { headers, tags: { operation: 'concurrent_search', term: term } }
    ]);

    const responses = http.batch(searchRequests);
    
    responses.forEach((response, index) => {
      const success = check(response, {
        'concurrent search success': (r) => r.status === 200,
        'concurrent search response time': (r) => r.timings.duration < 5000,
      });

      responseTime.add(response.timings.duration);
      
      if (success) {
        successfulRequests.add(1);
      } else {
        errorRate.add(1);
        failedRequests.add(1);
      }
    });
  });
}

function trackResponse(response, operationType) {
  const success = check(response, {
    [`${operationType} success`]: (r) => r.status >= 200 && r.status < 400,
    [`${operationType} response time`]: (r) => r.timings.duration < 10000,
  });

  responseTime.add(response.timings.duration);
  
  if (success) {
    successfulRequests.add(1);
  } else {
    errorRate.add(1);
    failedRequests.add(1);
  }
}

export function setup() {
  console.log('🔥 歯科システム ストレステスト開始');
  console.log('目標: システムの限界点を特定し、回復力をテスト');
  
  // System warmup
  const warmupResponse = http.get(BASE_URL);
  console.log(`システムウォームアップ: ${warmupResponse.status}`);
  
  return { 
    startTime: Date.now(),
    initialMemory: __ENV.INITIAL_MEMORY || 'unknown'
  };
}

export function teardown(data) {
  const duration = (Date.now() - data.startTime) / 1000;
  console.log(`🏁 ストレステスト完了 (実行時間: ${duration}秒)`);
  console.log('📊 システムの限界点とパフォーマンス特性を分析してください');
  console.log('⚠️  高負荷時のエラー率と応答時間の変化を確認してください');
}