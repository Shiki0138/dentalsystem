// K6 Load Testing Script for Dental System Performance Optimization
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');

// Test configuration based on specification requirements
export const options = {
  stages: [
    { duration: '2m', target: 20 },   // Ramp up to 20 users
    { duration: '3m', target: 50 },   // Stay at 50 users
    { duration: '2m', target: 100 },  // Ramp up to 100 users (spec requirement)
    { duration: '5m', target: 100 },  // Stay at 100 users (critical test)
    { duration: '1m', target: 120 },  // Spike test
    { duration: '2m', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<1000'], // 95% of requests under 1s (spec requirement)
    http_req_failed: ['rate<0.001'],   // Error rate under 0.1% (spec requirement)
    errors: ['rate<0.001'],            // Custom error rate under 0.1%
    http_req_duration: {
      'p(90)<800': true,               // 90% under 800ms
      'p(95)<1000': true,              // 95% under 1s (spec requirement)
      'p(99)<2000': true,              // 99% under 2s
    },
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';

// Test data
const patients = [
  { name: '田中太郎', phone: '090-1234-5678', email: 'tanaka@example.com' },
  { name: '佐藤花子', phone: '080-9876-5432', email: 'sato@example.com' },
  { name: '鈴木次郎', phone: '070-1111-2222', email: 'suzuki@example.com' },
];

const appointments = [
  { treatment_type: '定期検診', notes: 'クリーニング希望' },
  { treatment_type: '虫歯治療', notes: '右上奥歯痛み' },
  { treatment_type: '歯石除去', notes: '歯周病予防' },
];

export default function () {
  // Test scenarios weighted by usage patterns
  const scenario = Math.random();
  
  if (scenario < 0.4) {
    // 40% - Browse appointments (most common action)
    testBrowseAppointments();
  } else if (scenario < 0.7) {
    // 30% - Search patients
    testPatientSearch();
  } else if (scenario < 0.85) {
    // 15% - Create appointment (booking process)
    testCreateAppointment();
  } else if (scenario < 0.95) {
    // 10% - View appointment details
    testAppointmentDetails();
  } else {
    // 5% - API endpoints
    testApiEndpoints();
  }
  
  sleep(1);
}

function testBrowseAppointments() {
  // Test appointment listing with various filters
  const today = new Date().toISOString().split('T')[0];
  
  const urls = [
    `${BASE_URL}/appointments`,
    `${BASE_URL}/appointments?status=booked`,
    `${BASE_URL}/appointments?from_date=${today}`,
    `${BASE_URL}/appointments?page=2`,
  ];
  
  const url = urls[Math.floor(Math.random() * urls.length)];
  const response = http.get(url);
  
  const success = check(response, {
    'appointments page loaded': (r) => r.status === 200,
    'response time < 1s': (r) => r.timings.duration < 1000,
    'contains appointment data': (r) => r.body.includes('appointment') || r.body.includes('予約'),
  });
  
  errorRate.add(!success);
}

function testPatientSearch() {
  // Test patient search functionality
  const searchTerms = ['田中', '090', 'tanaka', '太郎'];
  const term = searchTerms[Math.floor(Math.random() * searchTerms.length)];
  
  const response = http.get(`${BASE_URL}/appointments/search_patients?q=${term}`);
  
  const success = check(response, {
    'patient search successful': (r) => r.status === 200,
    'search response time < 500ms': (r) => r.timings.duration < 500,
    'valid JSON response': (r) => {
      try {
        JSON.parse(r.body);
        return true;
      } catch {
        return false;
      }
    },
  });
  
  errorRate.add(!success);
}

function testCreateAppointment() {
  // Test appointment creation process
  const patient = patients[Math.floor(Math.random() * patients.length)];
  const appointment = appointments[Math.floor(Math.random() * appointments.length)];
  
  // First, get available slots
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  const dateStr = tomorrow.toISOString().split('T')[0];
  
  const slotsResponse = http.get(`${BASE_URL}/appointments/available_slots?date=${dateStr}`);
  
  const slotsSuccess = check(slotsResponse, {
    'available slots loaded': (r) => r.status === 200,
    'slots response time < 300ms': (r) => r.timings.duration < 300,
  });
  
  if (slotsSuccess) {
    // Simulate appointment creation form
    const formResponse = http.get(`${BASE_URL}/appointments/new`);
    
    const formSuccess = check(formResponse, {
      'new appointment form loaded': (r) => r.status === 200,
      'form response time < 800ms': (r) => r.timings.duration < 800,
    });
    
    errorRate.add(!formSuccess);
  }
  
  errorRate.add(!slotsSuccess);
}

function testAppointmentDetails() {
  // Test viewing appointment details
  const appointmentId = Math.floor(Math.random() * 100) + 1; // Simulate existing IDs
  
  const response = http.get(`${BASE_URL}/appointments/${appointmentId}`);
  
  const success = check(response, {
    'appointment details loaded': (r) => r.status === 200 || r.status === 404, // 404 is acceptable
    'details response time < 600ms': (r) => r.timings.duration < 600,
  });
  
  errorRate.add(!success);
}

function testApiEndpoints() {
  // Test API performance
  const endpoints = [
    '/api/v1/patients',
    '/api/v1/appointments',
    '/up', // Health check
  ];
  
  const endpoint = endpoints[Math.floor(Math.random() * endpoints.length)];
  const response = http.get(`${BASE_URL}${endpoint}`);
  
  const success = check(response, {
    'API endpoint responsive': (r) => r.status === 200,
    'API response time < 400ms': (r) => r.timings.duration < 400,
  });
  
  errorRate.add(!success);
}

// Test scenarios for specific performance requirements
export function testAppointmentBookingFlow() {
  // Test the critical 30-second booking flow requirement
  const startTime = new Date().getTime();
  
  // Step 1: Patient search (target: <200ms)
  const searchStart = new Date().getTime();
  const searchResponse = http.get(`${BASE_URL}/book/search_patients?q=田中`);
  const searchTime = new Date().getTime() - searchStart;
  
  check(searchResponse, {
    'patient search works': (r) => r.status === 200,
    'patient search under 200ms': () => searchTime < 200,
  });
  
  // Step 2: Check available slots (target: <300ms)
  const slotsStart = new Date().getTime();
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  const dateStr = tomorrow.toISOString().split('T')[0];
  
  const slotsResponse = http.get(`${BASE_URL}/book/available_slots?date=${dateStr}`);
  const slotsTime = new Date().getTime() - slotsStart;
  
  check(slotsResponse, {
    'slots check works': (r) => r.status === 200,
    'slots check under 300ms': () => slotsTime < 300,
  });
  
  // Step 3: Load manual booking form (target: <500ms)
  const formStart = new Date().getTime();
  const formResponse = http.get(`${BASE_URL}/book/manual`);
  const formTime = new Date().getTime() - formStart;
  
  check(formResponse, {
    'booking form loads': (r) => r.status === 200,
    'booking form under 500ms': () => formTime < 500,
  });
  
  // Step 4: Submit booking (simulate form submission)
  const submitStart = new Date().getTime();
  const submitResponse = http.post(`${BASE_URL}/book/manual`, {
    'patient_name': '田中太郎',
    'treatment_type': '定期検診',
    'appointment_date': dateStr,
    'appointment_time': '10:00'
  });
  const submitTime = new Date().getTime() - submitStart;
  
  check(submitResponse, {
    'booking submission processed': (r) => r.status === 200 || r.status === 302,
    'booking submission under 1s': () => submitTime < 1000,
  });
  
  const totalTime = new Date().getTime() - startTime;
  
  check({ totalTime }, {
    'complete booking flow under 30s': () => totalTime < 30000, // 30 seconds requirement
    'complete booking flow under 10s': () => totalTime < 10000, // Optimized target
  });
  
  // Log performance metrics
  console.log(`Booking flow performance:
    - Patient search: ${searchTime}ms
    - Available slots: ${slotsTime}ms
    - Form load: ${formTime}ms
    - Submission: ${submitTime}ms
    - Total: ${totalTime}ms`);
}

// Memory and resource monitoring
export function handleSummary(data) {
  return {
    'load_test_results.json': JSON.stringify(data),
    stdout: `
Performance Test Results:
========================
Total Requests: ${data.metrics.http_reqs.count}
Failed Requests: ${data.metrics.http_req_failed.count}
Average Response Time: ${data.metrics.http_req_duration.avg.toFixed(2)}ms
95th Percentile: ${data.metrics.http_req_duration['p(95)'].toFixed(2)}ms
99th Percentile: ${data.metrics.http_req_duration['p(99)'].toFixed(2)}ms

Thresholds:
- 95% of requests under 1s: ${data.metrics.http_req_duration['p(95)'] < 1000 ? 'PASS' : 'FAIL'}
- Error rate under 1%: ${data.metrics.http_req_failed.rate < 0.01 ? 'PASS' : 'FAIL'}

Performance Grade: ${getPerformanceGrade(data)}
`,
  };
}

function getPerformanceGrade(data) {
  const p95 = data.metrics.http_req_duration['p(95)'];
  const errorRate = data.metrics.http_req_failed.rate;
  
  if (p95 < 500 && errorRate < 0.001) return 'A+ (Excellent)';
  if (p95 < 1000 && errorRate < 0.01) return 'A (Good)';
  if (p95 < 2000 && errorRate < 0.05) return 'B (Acceptable)';
  return 'C (Needs Optimization)';
}