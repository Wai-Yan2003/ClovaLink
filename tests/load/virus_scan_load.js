/**
 * k6 Load Test for ClovaLink Virus Scanning
 * 
 * Tests the resilience of the virus scanning system under load:
 * - Circuit breaker behavior
 * - Queue backpressure
 * - Exponential backoff
 * - Concurrent upload handling
 * 
 * Usage:
 *   k6 run virus_scan_load.js
 *   k6 run --vus 100 --duration 1m virus_scan_load.js  # Quick test
 *   k6 run --env BASE_URL=http://localhost:8080 virus_scan_load.js
 */

import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';
import { SharedArray } from 'k6/data';
import { randomString } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js';

// Configuration
const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const TENANT_ID = __ENV.TENANT_ID || '11111111-1111-1111-1111-111111111111';

// Custom metrics
const uploadSuccess = new Rate('upload_success');
const uploadDuration = new Trend('upload_duration', true);
const scanQueueSize = new Trend('scan_queue_size');
const loginSuccess = new Rate('login_success');

// Test configuration
export const options = {
  scenarios: {
    // Gradual ramp-up to 1000 concurrent users
    upload_stress: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 100 },   // Warm up: ramp to 100 users
        { duration: '1m', target: 500 },    // Ramp to 500 users
        { duration: '1m', target: 1000 },   // Ramp to 1000 users
        { duration: '2m', target: 1000 },   // Hold at 1000 users
        { duration: '30s', target: 0 },     // Ramp down
      ],
      gracefulRampDown: '30s',
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<10000'],     // 95% of requests under 10s
    http_req_failed: ['rate<0.2'],          // Less than 20% failure rate
    upload_success: ['rate>0.8'],           // At least 80% uploads succeed
    login_success: ['rate>0.95'],           // At least 95% logins succeed
  },
};

// Generate a small test file (not EICAR to avoid quarantine during load test)
function generateTestFile() {
  const content = `Test file generated at ${new Date().toISOString()}\n` +
    `VU: ${__VU}, Iteration: ${__ITER}\n` +
    `Random data: ${randomString(100)}\n`;
  return content;
}

// Create a unique test user for this VU
function createTestUser(vuId) {
  const email = `loadtest_user_${vuId}_${Date.now()}@test.local`;
  const password = 'LoadTest123!';
  
  const payload = JSON.stringify({
    email: email,
    password: password,
    name: `Load Test User ${vuId}`,
  });

  const res = http.post(`${BASE_URL}/api/auth/register`, payload, {
    headers: { 'Content-Type': 'application/json' },
    tags: { name: 'register' },
  });

  if (res.status === 201 || res.status === 200) {
    return { email, password, created: true };
  } else if (res.status === 409) {
    // User already exists, that's fine
    return { email, password, created: false };
  } else {
    console.error(`Failed to create user: ${res.status} - ${res.body}`);
    return null;
  }
}

// Login and get JWT token
function login(email, password) {
  const payload = JSON.stringify({ email, password });
  
  const res = http.post(`${BASE_URL}/api/auth/login`, payload, {
    headers: { 'Content-Type': 'application/json' },
    tags: { name: 'login' },
  });

  const success = res.status === 200;
  loginSuccess.add(success);

  if (success) {
    try {
      const body = JSON.parse(res.body);
      return body.token;
    } catch (e) {
      console.error(`Failed to parse login response: ${e}`);
      return null;
    }
  } else {
    console.error(`Login failed: ${res.status} - ${res.body}`);
    return null;
  }
}

// Upload a file
function uploadFile(token, filename, content) {
  const boundary = '----k6FormBoundary' + randomString(16);
  
  const body = `--${boundary}\r\n` +
    `Content-Disposition: form-data; name="file"; filename="${filename}"\r\n` +
    `Content-Type: text/plain\r\n\r\n` +
    `${content}\r\n` +
    `--${boundary}\r\n` +
    `Content-Disposition: form-data; name="parent_id"\r\n\r\n` +
    `\r\n` +
    `--${boundary}--\r\n`;

  const startTime = Date.now();
  
  const res = http.post(`${BASE_URL}/api/upload/${TENANT_ID}`, body, {
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': `multipart/form-data; boundary=${boundary}`,
    },
    tags: { name: 'upload' },
    timeout: '30s',
  });

  const duration = Date.now() - startTime;
  uploadDuration.add(duration);

  const success = res.status === 200 || res.status === 201;
  uploadSuccess.add(success);

  if (!success) {
    console.error(`Upload failed: ${res.status} - ${res.body?.substring(0, 200)}`);
  }

  return { success, status: res.status, duration };
}

// Check virus scan queue metrics (if endpoint exists)
function checkQueueMetrics(token) {
  const res = http.get(`${BASE_URL}/api/admin/virus-scan/metrics`, {
    headers: { 'Authorization': `Bearer ${token}` },
    tags: { name: 'metrics' },
  });

  if (res.status === 200) {
    try {
      const metrics = JSON.parse(res.body);
      if (metrics.queue_size !== undefined) {
        scanQueueSize.add(metrics.queue_size);
      }
      return metrics;
    } catch (e) {
      return null;
    }
  }
  return null;
}

// Setup function - runs once per VU
export function setup() {
  console.log(`Starting load test against ${BASE_URL}`);
  console.log(`Tenant ID: ${TENANT_ID}`);
  
  // Login as admin for metrics checking (password from seed data)
  const adminRes = http.post(`${BASE_URL}/api/auth/login`, JSON.stringify({
    email: 'admin@acme.com',
    password: 'password123',
  }), {
    headers: { 'Content-Type': 'application/json' },
  });

  let adminToken = null;
  if (adminRes.status === 200) {
    try {
      adminToken = JSON.parse(adminRes.body).token;
      console.log('Admin login successful');
    } catch (e) {
      console.error('Failed to parse admin login response');
    }
  } else {
    console.error(`Admin login failed: ${adminRes.status}`);
  }

  return { adminToken };
}

// Main test function - runs for each VU iteration
export default function(data) {
  const vuId = __VU;
  const iteration = __ITER;

  group('User Setup', function() {
    // Each VU creates its own user on first iteration
    if (iteration === 0) {
      const user = createTestUser(vuId);
      if (!user) {
        console.error(`VU ${vuId}: Failed to create user, skipping iteration`);
        sleep(1);
        return;
      }
      
      // Store credentials in VU context
      __ENV[`USER_EMAIL_${vuId}`] = user.email;
      __ENV[`USER_PASSWORD_${vuId}`] = user.password;
    }
  });

  // Get stored credentials
  const email = __ENV[`USER_EMAIL_${vuId}`] || `loadtest_user_${vuId}@test.local`;
  const password = __ENV[`USER_PASSWORD_${vuId}`] || 'LoadTest123!';

  let token = null;

  group('Authentication', function() {
    token = login(email, password);
    if (!token) {
      // Try with default test credentials (from seed data)
      token = login('admin@acme.com', 'password123');
    }
  });

  if (!token) {
    console.error(`VU ${vuId}: Failed to authenticate, skipping iteration`);
    sleep(1);
    return;
  }

  group('File Upload', function() {
    const filename = `loadtest_${vuId}_${iteration}_${Date.now()}.txt`;
    const content = generateTestFile();
    
    const result = uploadFile(token, filename, content);
    
    check(result, {
      'upload succeeded': (r) => r.success,
      'upload under 5s': (r) => r.duration < 5000,
      'upload under 10s': (r) => r.duration < 10000,
    });
  });

  // Occasionally check queue metrics (every 10th iteration for admin VUs)
  if (vuId === 1 && iteration % 10 === 0 && data.adminToken) {
    group('Metrics Check', function() {
      const metrics = checkQueueMetrics(data.adminToken);
      if (metrics) {
        console.log(`Queue metrics: ${JSON.stringify(metrics)}`);
      }
    });
  }

  // Small random delay between iterations to simulate realistic user behavior
  sleep(Math.random() * 2 + 0.5);
}

// Teardown function - runs once at the end
export function teardown(data) {
  console.log('Load test completed');
  console.log('Check the k6 output for detailed metrics');
}

