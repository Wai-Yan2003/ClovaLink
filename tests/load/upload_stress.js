/**
 * Direct Upload Stress Test
 * 
 * Bypasses login by using a pre-obtained token.
 * Run setup.sh first to get a token, or use the ADMIN_TOKEN env var.
 * 
 * Usage:
 *   # Get token first
 *   TOKEN=$(curl -s -X POST http://localhost:3000/api/auth/login \
 *     -H "Content-Type: application/json" \
 *     -d '{"email":"admin@acme.com","password":"password123"}' | jq -r '.token')
 *   
 *   # Run test with token
 *   k6 run --env TOKEN=$TOKEN tests/load/upload_stress.js
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';
import { randomString } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js';

// Configuration
const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';
const TENANT_ID = __ENV.TENANT_ID || '11111111-1111-1111-1111-111111111111';
const TOKEN = __ENV.TOKEN || '';

// Custom metrics
const uploadSuccess = new Rate('upload_success');
const uploadDuration = new Trend('upload_duration', true);
const uploadsCompleted = new Counter('uploads_completed');
const virusScanQueued = new Counter('virus_scan_queued');

export const options = {
  scenarios: {
    upload_stress: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '10s', target: 50 },    // Warm up
        { duration: '30s', target: 200 },   // Ramp to 200
        { duration: '1m', target: 500 },    // Ramp to 500
        { duration: '1m', target: 500 },    // Hold
        { duration: '20s', target: 0 },     // Ramp down
      ],
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<10000'],
    upload_success: ['rate>0.7'],
  },
};

function generateTestFile() {
  // Generate ~1KB test file
  return `Test file for load testing\n` +
    `Generated: ${new Date().toISOString()}\n` +
    `VU: ${__VU}, Iteration: ${__ITER}\n` +
    `Random: ${randomString(900)}\n`;
}

function uploadFile(token, filename, content) {
  const boundary = '----k6FormBoundary' + randomString(16);
  
  const body = `--${boundary}\r\n` +
    `Content-Disposition: form-data; name="file"; filename="${filename}"\r\n` +
    `Content-Type: text/plain\r\n\r\n` +
    `${content}\r\n` +
    `--${boundary}--\r\n`;

  const start = Date.now();
  
  const res = http.post(`${BASE_URL}/api/upload/${TENANT_ID}`, body, {
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': `multipart/form-data; boundary=${boundary}`,
    },
    timeout: '60s',
  });

  const duration = Date.now() - start;
  uploadDuration.add(duration);

  const success = res.status === 200 || res.status === 201;
  uploadSuccess.add(success);

  if (success) {
    uploadsCompleted.add(1);
    virusScanQueued.add(1);
  }

  return { success, status: res.status, duration };
}

export function setup() {
  if (!TOKEN) {
    console.error('ERROR: No TOKEN provided!');
    console.error('Get a token first:');
    console.error('  TOKEN=$(curl -s -X POST http://localhost:3000/api/auth/login \\');
    console.error('    -H "Content-Type: application/json" \\');
    console.error('    -d \'{"email":"admin@acme.com","password":"password123"}\' | jq -r \'.token\')');
    console.error('  k6 run --env TOKEN=$TOKEN tests/load/upload_stress.js');
    return { token: null };
  }
  
  console.log(`Upload stress test against ${BASE_URL}`);
  console.log(`Tenant: ${TENANT_ID}`);
  return { token: TOKEN };
}

export default function(data) {
  if (!data.token) {
    sleep(1);
    return;
  }

  const filename = `stress_${__VU}_${__ITER}_${Date.now()}.txt`;
  const content = generateTestFile();
  
  const result = uploadFile(data.token, filename, content);
  
  check(result, {
    'upload succeeded': (r) => r.success,
    'upload under 5s': (r) => r.duration < 5000,
  });

  // Small delay between uploads
  sleep(Math.random() * 0.5);
}

export function teardown(data) {
  console.log('Upload stress test completed');
}

