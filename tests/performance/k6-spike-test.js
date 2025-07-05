// 🦷 Dental System - k6 Spike Test
// Spike testing for sudden traffic surges

import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Rate, Trend, Counter, Gauge } from 'k6/metrics';

// Custom metrics for spike testing
export const spikeErrorRate = new Rate('spike_errors');
export const spikeResponseTime = new Trend('spike_response_time');
export const activeSessions = new Gauge('active_sessions');
export const spikeRequests = new Counter('spike_requests');
export const recoveryTime = new Trend('recovery_time');

// Spike test configuration
export let options = {
  stages: [
    // Normal baseline
    { duration: '2m', target: 10 },    // Low baseline traffic
    
    // Sudden spike
    { duration: '30s', target: 300 },  // Immediate spike to 300 users
    { duration: '1m', target: 300 },   // Maintain spike
    
    // Another spike
    { duration: '30s', target: 500 },  // Even higher spike
    { duration: '1m', target: 500 },   // Maintain higher spike
    
    // Recovery phase
    { duration: '30s', target: 50 },   // Quick drop
    { duration: '2m', target: 10 },    // Return to baseline
    
    // Final spike test
    { duration: '15s', target: 600 },  // Very sudden, very high spike
    { duration: '30s', target: 600 },  // Brief maintenance
    { duration: '1m', target: 0 },     // Complete shutdown
  ],
  
  // Spike test thresholds
  thresholds: {
    // System should maintain some level of service during spikes
    'http_req_duration{p(95)}': ['p(95)<10000'], // Allow up to 10s during spikes
    'http_req_failed': ['rate<0.25'], // Allow up to 25% failures during extreme spikes
    
    // Recovery metrics
    'spike_response_time': ['p(95)<15000'],
    'spike_errors': ['rate<0.3'],
    
    // Baseline performance should recover
    'http_req_duration{baseline:yes}': ['p(95)<2000'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';
const API_URL = `${BASE_URL}/api/v1`;

// Critical system endpoints to test during spikes
const criticalEndpoints = [
  { url: `${BASE_URL}/users/sign_in`, name: 'login_page', critical: true },
  { url: `${API_URL}/auth/login`, name: 'auth_api', critical: true, method: 'POST' },
  { url: `${BASE_URL}/dashboard`, name: 'dashboard', critical: true },
  { url: `${API_URL}/patients`, name: 'patients_api', critical: false },
  { url: `${API_URL}/appointments`, name: 'appointments_api', critical: false },
  { url: `${API_URL}/patients/search`, name: 'search_api', critical: false },
];

function getCurrentStage() {
  const vus = __VU;
  if (vus <= 50) return 'baseline';
  if (vus <= 300) return 'spike_1';
  if (vus <= 500) return 'spike_2';
  if (vus <= 600) return 'spike_3';
  return 'unknown';
}

function authenticateForSpike() {
  const response = http.get(`${BASE_URL}/users/sign_in`, {
    tags: { endpoint: 'login_page', stage: getCurrentStage() }
  });
  
  const csrfMatch = response.body.match(/name="csrf-token" content="([^"]+)"/);
  const csrfToken = csrfMatch ? csrfMatch[1] : null;
  
  if (!csrfToken) {
    spikeErrorRate.add(1);
    return null;
  }
  
  const loginResponse = http.post(`${API_URL}/auth/login`, JSON.stringify({
    email: 'spike.test@dental.com',
    password: 'SpikeTest123!'
  }), {
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': csrfToken,
    },
    tags: { endpoint: 'auth_api', stage: getCurrentStage() }
  });

  const authSuccess = check(loginResponse, {
    'spike auth successful': (r) => r.status === 200,
    'spike auth response time acceptable': (r) => r.timings.duration < 5000,
  });

  spikeResponseTime.add(loginResponse.timings.duration);
  spikeRequests.add(1);

  if (authSuccess && loginResponse.status === 200) {
    const loginData = JSON.parse(loginResponse.body);
    activeSessions.add(1);
    return {
      token: loginData.token,
      csrfToken: csrfToken
    };
  }
  
  spikeErrorRate.add(1);
  return null;
}

export default function() {
  const stage = getCurrentStage();
  const startTime = Date.now();
  
  group(`Spike Test - ${stage}`, function() {
    const auth = authenticateForSpike();
    
    if (!auth) {
      return;
    }

    const headers = {
      'Authorization': `Bearer ${auth.token}`,
      'Content-Type': 'application/json',
      'X-CSRF-Token': auth.csrfToken,
    };

    // Test critical endpoints first
    group('Critical Endpoints Test', function() {
      testCriticalEndpoints(headers, stage);
    });

    // Test system resilience based on current stage
    switch (stage) {
      case 'baseline':
        testBaselinePerformance(headers);
        break;
      case 'spike_1':
      case 'spike_2':
      case 'spike_3':
        testSpikeResilience(headers, stage);
        break;
    }

    // Measure individual session duration for recovery metrics
    const sessionDuration = Date.now() - startTime;
    recoveryTime.add(sessionDuration);
  });

  // Variable sleep based on load stage
  const sleepTime = stage === 'baseline' ? Math.random() * 2 + 1 : Math.random() * 0.3;
  sleep(sleepTime);
}

function testCriticalEndpoints(headers, stage) {
  const criticalTests = [
    {
      name: 'dashboard_load',
      request: () => http.get(`${BASE_URL}/dashboard`, { 
        headers, 
        tags: { endpoint: 'dashboard', stage, critical: 'true' }
      })
    },
    {
      name: 'patient_list',
      request: () => http.get(`${API_URL}/patients?limit=10`, { 
        headers, 
        tags: { endpoint: 'patients_limited', stage, critical: 'true' }
      })
    },
    {
      name: 'today_appointments',
      request: () => http.get(`${API_URL}/appointments/today`, { 
        headers, 
        tags: { endpoint: 'today_appointments', stage, critical: 'true' }
      })
    }
  ];

  criticalTests.forEach(test => {
    const response = test.request();
    
    const success = check(response, {
      [`${test.name} available during spike`]: (r) => r.status === 200,
      [`${test.name} response time under spike`]: (r) => r.timings.duration < 15000,
    });

    spikeResponseTime.add(response.timings.duration);
    spikeRequests.add(1);

    if (!success) {
      spikeErrorRate.add(1);
    }
  });
}

function testBaselinePerformance(headers) {
  group('Baseline Performance', function() {
    // Normal user behavior during baseline
    const operations = [
      () => http.get(`${API_URL}/patients`, { 
        headers, 
        tags: { baseline: 'yes', operation: 'list_patients' }
      }),
      () => http.get(`${API_URL}/appointments`, { 
        headers, 
        tags: { baseline: 'yes', operation: 'list_appointments' }
      }),
      () => http.get(`${API_URL}/patients/search?q=田中`, { 
        headers, 
        tags: { baseline: 'yes', operation: 'search_patients' }
      }),
    ];

    const operation = operations[Math.floor(Math.random() * operations.length)];
    const response = operation();

    check(response, {
      'baseline operation successful': (r) => r.status === 200,
      'baseline response time optimal': (r) => r.timings.duration < 1000,
    });

    spikeResponseTime.add(response.timings.duration);
    spikeRequests.add(1);
  });
}

function testSpikeResilience(headers, stage) {
  group(`Spike Resilience - ${stage}`, function() {
    // Different behavior during spikes - focus on lightweight operations
    const lightweightOps = [
      () => http.get(`${API_URL}/health`, { 
        headers, 
        tags: { spike: 'yes', operation: 'health_check', stage }
      }),
      () => http.get(`${API_URL}/patients/count`, { 
        headers, 
        tags: { spike: 'yes', operation: 'count_only', stage }
      }),
      () => http.get(`${BASE_URL}/ping`, { 
        headers, 
        tags: { spike: 'yes', operation: 'ping', stage }
      }),
    ];

    // Heavy operations (test system degradation)
    const heavyOps = [
      () => http.get(`${API_URL}/patients`, { 
        headers, 
        tags: { spike: 'yes', operation: 'full_list', stage }
      }),
      () => http.get(`${API_URL}/reports/dashboard`, { 
        headers, 
        tags: { spike: 'yes', operation: 'reports', stage }
      }),
    ];

    // 80% lightweight, 20% heavy operations during spikes
    const useHeavy = Math.random() < 0.2;
    const operations = useHeavy ? heavyOps : lightweightOps;
    
    const operation = operations[Math.floor(Math.random() * operations.length)];
    const response = operation();

    const isLightweight = !useHeavy;
    const timeLimit = isLightweight ? 5000 : 20000;

    const success = check(response, {
      'spike operation responds': (r) => r.status === 200 || r.status === 503, // 503 acceptable under extreme load
      'spike operation within time limit': (r) => r.timings.duration < timeLimit,
    });

    spikeResponseTime.add(response.timings.duration);
    spikeRequests.add(1);

    if (!success || response.status >= 500) {
      spikeErrorRate.add(1);
    }

    // Test concurrent requests during spike
    if (Math.random() < 0.1) { // 10% chance
      testConcurrentSpikeBehavior(headers, stage);
    }
  });
}

function testConcurrentSpikeBehavior(headers, stage) {
  group('Concurrent Spike Behavior', function() {
    // Simulate multiple rapid requests from the same user
    const rapidRequests = [
      ['GET', `${API_URL}/patients/count`, null, { headers, tags: { concurrent: 'yes', stage } }],
      ['GET', `${API_URL}/appointments/count`, null, { headers, tags: { concurrent: 'yes', stage } }],
      ['GET', `${API_URL}/dashboard/summary`, null, { headers, tags: { concurrent: 'yes', stage } }],
    ];

    const responses = http.batch(rapidRequests);
    
    responses.forEach((response, index) => {
      const success = check(response, {
        'concurrent request completes': (r) => r.status < 500,
        'concurrent request timely': (r) => r.timings.duration < 10000,
      });

      spikeResponseTime.add(response.timings.duration);
      spikeRequests.add(1);

      if (!success) {
        spikeErrorRate.add(1);
      }
    });
  });
}

// Circuit breaker test
export function testCircuitBreaker() {
  group('Circuit Breaker Test', function() {
    // Rapid fire requests to trigger circuit breaker
    for (let i = 0; i < 20; i++) {
      const response = http.get(`${API_URL}/patients`, {
        tags: { test: 'circuit_breaker' }
      });
      
      check(response, {
        'circuit breaker responds appropriately': (r) => 
          r.status === 200 || r.status === 503 || r.status === 429,
      });
      
      if (response.status === 503 || response.status === 429) {
        console.log(`Circuit breaker activated at request ${i + 1}`);
        break;
      }
      
      sleep(0.1);
    }
  });
}

export function setup() {
  console.log('⚡ 歯科システム スパイクテスト開始');
  console.log('目標: 突然のトラフィック急増に対するシステムの回復力をテスト');
  
  // Pre-spike system check
  const healthCheck = http.get(`${BASE_URL}/health`);
  console.log(`システムヘルスチェック: ${healthCheck.status}`);
  
  return { 
    startTime: Date.now(),
    preSpikePeformance: healthCheck.timings.duration
  };
}

export function teardown(data) {
  const duration = (Date.now() - data.startTime) / 1000;
  console.log(`⚡ スパイクテスト完了 (実行時間: ${duration}秒)`);
  console.log('📊 スパイク時の応答性とシステム回復力を分析してください');
  console.log('🔄 自動スケーリングとサーキットブレーカーの動作を確認してください');
  
  // Post-spike health check
  const postSpikeCheck = http.get(`${BASE_URL}/health`);
  console.log(`スパイク後システム状態: ${postSpikeCheck.status} (${postSpikeCheck.timings.duration}ms)`);
}