// 🦷 Dental System - k6 Performance Load Tests
// Performance testing with 95th percentile < 1s and 100 virtual users

import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// Custom metrics
export const errorRate = new Rate('errors');
export const responseTime = new Trend('response_time');
export const throughput = new Counter('requests_total');

// Test configuration
export let options = {
  stages: [
    // Ramp-up phase
    { duration: '2m', target: 20 },   // Gradually increase to 20 users
    { duration: '3m', target: 50 },   // Scale to 50 users
    { duration: '5m', target: 100 },  // Scale to 100 users (target load)
    { duration: '10m', target: 100 }, // Maintain 100 users for 10 minutes
    { duration: '3m', target: 50 },   // Scale down to 50 users
    { duration: '2m', target: 0 },    // Graceful shutdown
  ],
  
  // Performance thresholds
  thresholds: {
    // 95th percentile response time must be < 1000ms
    'http_req_duration{p(95)}': ['p(95)<1000'],
    
    // 99th percentile response time should be < 2000ms
    'http_req_duration{p(99)}': ['p(99)<2000'],
    
    // Average response time should be < 500ms
    'http_req_duration': ['avg<500'],
    
    // Error rate should be < 1%
    'http_req_failed': ['rate<0.01'],
    
    // 95% of requests should complete successfully
    'checks': ['rate>0.95'],
    
    // Custom thresholds
    'errors': ['rate<0.01'],
    'response_time': ['p(95)<1000'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';
const API_URL = `${BASE_URL}/api/v1`;

// Test data
const users = [
  { email: 'doctor1@dental.com', password: 'TestPass123!', role: 'doctor' },
  { email: 'doctor2@dental.com', password: 'TestPass123!', role: 'doctor' },
  { email: 'receptionist@dental.com', password: 'TestPass123!', role: 'receptionist' },
];

const patientData = [
  { name: '田中太郎', phone: '090-1234-5678', email: 'tanaka@example.com' },
  { name: '佐藤花子', phone: '080-9876-5432', email: 'sato@example.com' },
  { name: '山田次郎', phone: '070-5555-6666', email: 'yamada@example.com' },
];

// Utility functions
function getRandomUser() {
  return users[Math.floor(Math.random() * users.length)];
}

function getRandomPatient() {
  return patientData[Math.floor(Math.random() * patientData.length)];
}

function getCsrfToken() {
  const response = http.get(`${BASE_URL}/users/sign_in`);
  const csrfMatch = response.body.match(/name="csrf-token" content="([^"]+)"/);
  return csrfMatch ? csrfMatch[1] : null;
}

function authenticateUser(user) {
  const csrfToken = getCsrfToken();
  
  const loginResponse = http.post(`${API_URL}/auth/login`, JSON.stringify({
    email: user.email,
    password: user.password
  }), {
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': csrfToken,
    },
    tags: { endpoint: 'auth_login' }
  });

  check(loginResponse, {
    'login successful': (r) => r.status === 200,
    'login response time < 1s': (r) => r.timings.duration < 1000,
  });

  if (loginResponse.status === 200) {
    const loginData = JSON.parse(loginResponse.body);
    return {
      token: loginData.token,
      csrfToken: csrfToken,
      user: loginData.user
    };
  }
  
  return null;
}

// Main test scenario
export default function() {
  const user = getRandomUser();
  
  group('Authentication Flow', function() {
    const auth = authenticateUser(user);
    
    if (!auth) {
      errorRate.add(1);
      return;
    }

    const headers = {
      'Authorization': `Bearer ${auth.token}`,
      'Content-Type': 'application/json',
      'X-CSRF-Token': auth.csrfToken,
    };

    group('Dashboard Load', function() {
      const dashboardResponse = http.get(`${BASE_URL}/dashboard`, {
        headers: headers,
        tags: { endpoint: 'dashboard' }
      });

      const dashboardCheck = check(dashboardResponse, {
        'dashboard loads successfully': (r) => r.status === 200,
        'dashboard response time < 1s': (r) => r.timings.duration < 1000,
        'dashboard contains key metrics': (r) => r.body.includes('daily-appointments'),
      });

      responseTime.add(dashboardResponse.timings.duration);
      throughput.add(1);
      if (!dashboardCheck) errorRate.add(1);
    });

    group('Patient Management', function() {
      // List patients
      const patientsResponse = http.get(`${API_URL}/patients`, {
        headers: headers,
        tags: { endpoint: 'patients_list' }
      });

      check(patientsResponse, {
        'patients list loads': (r) => r.status === 200,
        'patients list response time < 500ms': (r) => r.timings.duration < 500,
      });

      // Search patients
      const searchResponse = http.get(`${API_URL}/patients/search?q=田中`, {
        headers: headers,
        tags: { endpoint: 'patients_search' }
      });

      check(searchResponse, {
        'patient search works': (r) => r.status === 200,
        'search response time < 300ms': (r) => r.timings.duration < 300,
      });

      // Create patient (for write operations)
      if (Math.random() < 0.3) { // 30% chance to create patient
        const patient = getRandomPatient();
        const createResponse = http.post(`${API_URL}/patients`, JSON.stringify({
          patient: {
            ...patient,
            name: `${patient.name}_${Date.now()}` // Unique name
          }
        }), {
          headers: headers,
          tags: { endpoint: 'patients_create' }
        });

        check(createResponse, {
          'patient creation successful': (r) => r.status === 201,
          'patient creation response time < 800ms': (r) => r.timings.duration < 800,
        });
      }

      responseTime.add(patientsResponse.timings.duration);
      throughput.add(1);
    });

    group('Appointment Management', function() {
      // List appointments
      const appointmentsResponse = http.get(`${API_URL}/appointments`, {
        headers: headers,
        tags: { endpoint: 'appointments_list' }
      });

      check(appointmentsResponse, {
        'appointments list loads': (r) => r.status === 200,
        'appointments response time < 600ms': (r) => r.timings.duration < 600,
      });

      // Filter appointments by date
      const today = new Date().toISOString().split('T')[0];
      const filterResponse = http.get(`${API_URL}/appointments?date=${today}`, {
        headers: headers,
        tags: { endpoint: 'appointments_filter' }
      });

      check(filterResponse, {
        'appointment filtering works': (r) => r.status === 200,
        'filter response time < 400ms': (r) => r.timings.duration < 400,
      });

      // Create appointment (for write operations)
      if (Math.random() < 0.2) { // 20% chance to create appointment
        const appointmentData = {
          patient_id: 1,
          appointment_date: today,
          appointment_time: '10:00',
          treatment_type: '定期検診',
          notes: `Performance test ${Date.now()}`
        };

        const createResponse = http.post(`${API_URL}/appointments`, JSON.stringify({
          appointment: appointmentData
        }), {
          headers: headers,
          tags: { endpoint: 'appointments_create' }
        });

        check(createResponse, {
          'appointment creation works': (r) => r.status === 201,
          'appointment creation response time < 1s': (r) => r.timings.duration < 1000,
        });
      }

      responseTime.add(appointmentsResponse.timings.duration);
      throughput.add(1);
    });

    group('Calendar View', function() {
      const calendarResponse = http.get(`${BASE_URL}/calendar`, {
        headers: headers,
        tags: { endpoint: 'calendar' }
      });

      check(calendarResponse, {
        'calendar loads successfully': (r) => r.status === 200,
        'calendar response time < 800ms': (r) => r.timings.duration < 800,
      });

      responseTime.add(calendarResponse.timings.duration);
      throughput.add(1);
    });

    group('API Performance Tests', function() {
      // Concurrent API calls simulation
      const responses = http.batch([
        ['GET', `${API_URL}/patients/stats`, null, { headers: headers, tags: { endpoint: 'stats' } }],
        ['GET', `${API_URL}/appointments/today`, null, { headers: headers, tags: { endpoint: 'today_appointments' } }],
        ['GET', `${API_URL}/dashboard/metrics`, null, { headers: headers, tags: { endpoint: 'metrics' } }],
      ]);

      responses.forEach((response, index) => {
        const endpoints = ['stats', 'today_appointments', 'metrics'];
        check(response, {
          [`${endpoints[index]} API responds correctly`]: (r) => r.status === 200,
          [`${endpoints[index]} response time < 500ms`]: (r) => r.timings.duration < 500,
        });
        
        responseTime.add(response.timings.duration);
        throughput.add(1);
      });
    });

    group('Database Intensive Operations', function() {
      // Complex search operation
      const complexSearchResponse = http.get(`${API_URL}/patients/search?q=田&age_min=20&age_max=60&treatment_type=定期検診`, {
        headers: headers,
        tags: { endpoint: 'complex_search' }
      });

      check(complexSearchResponse, {
        'complex search completes': (r) => r.status === 200,
        'complex search response time < 1s': (r) => r.timings.duration < 1000,
      });

      // Report generation simulation
      const reportResponse = http.get(`${API_URL}/reports/appointments?start_date=2025-01-01&end_date=2025-12-31`, {
        headers: headers,
        tags: { endpoint: 'reports' }
      });

      check(reportResponse, {
        'report generation works': (r) => r.status === 200,
        'report response time < 2s': (r) => r.timings.duration < 2000,
      });

      responseTime.add(complexSearchResponse.timings.duration);
      throughput.add(1);
    });
  });

  // Simulate realistic user behavior with think time
  sleep(Math.random() * 3 + 1); // 1-4 seconds think time
}

// Stress test scenario
export function stressTest() {
  const user = getRandomUser();
  const auth = authenticateUser(user);
  
  if (!auth) return;

  const headers = {
    'Authorization': `Bearer ${auth.token}`,
    'Content-Type': 'application/json',
    'X-CSRF-Token': auth.csrfToken,
  };

  // Rapid fire requests to test system limits
  for (let i = 0; i < 10; i++) {
    const response = http.get(`${API_URL}/patients`, {
      headers: headers,
      tags: { test_type: 'stress' }
    });
    
    check(response, {
      'stress test request succeeds': (r) => r.status === 200,
      'stress test response time acceptable': (r) => r.timings.duration < 2000,
    });
    
    sleep(0.1); // Minimal delay between requests
  }
}

// Spike test scenario
export function spikeTest() {
  const user = getRandomUser();
  const auth = authenticateUser(user);
  
  if (!auth) return;

  const headers = {
    'Authorization': `Bearer ${auth.token}`,
    'Content-Type': 'application/json',
    'X-CSRF-Token': auth.csrfToken,
  };

  // Simultaneous requests to test spike handling
  const responses = http.batch([
    ['GET', `${API_URL}/patients`, null, { headers: headers }],
    ['GET', `${API_URL}/appointments`, null, { headers: headers }],
    ['GET', `${API_URL}/dashboard/metrics`, null, { headers: headers }],
    ['GET', `${BASE_URL}/calendar`, null, { headers: headers }],
    ['GET', `${API_URL}/patients/search?q=test`, null, { headers: headers }],
  ]);

  responses.forEach(response => {
    check(response, {
      'spike test request succeeds': (r) => r.status === 200,
      'spike test maintains performance': (r) => r.timings.duration < 3000,
    });
  });
}

// Performance monitoring setup
export function setup() {
  console.log('🚀 歯科システム パフォーマンステスト開始');
  console.log('目標: 95パーセンタイル < 1秒, 100仮想ユーザー');
  
  // Warmup requests
  const warmupResponse = http.get(BASE_URL);
  console.log(`ウォームアップ完了: ${warmupResponse.status}`);
  
  return { startTime: Date.now() };
}

export function teardown(data) {
  const duration = (Date.now() - data.startTime) / 1000;
  console.log(`🏁 パフォーマンステスト完了 (実行時間: ${duration}秒)`);
  console.log('📊 詳細なメトリクスはk6レポートを確認してください');
}