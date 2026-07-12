/**
 * EcoWatch API smoke tests — run with: npm run test:api
 * Requires API server + PostgreSQL running.
 */
const BASE = process.env.API_URL || 'http://localhost:3000';

let passed = 0;
let failed = 0;
let authToken = '';

async function request(method, path, { body, token, multipart } = {}) {
  const headers = {};
  if (token) headers.Authorization = `Bearer ${token}`;
  let fetchBody = body;
  if (body && !multipart) {
    headers['Content-Type'] = 'application/json';
    fetchBody = JSON.stringify(body);
  }
  const res = await fetch(`${BASE}${path}`, { method, headers, body: fetchBody });
  const text = await res.text();
  let data;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }
  return { status: res.status, data };
}

function assert(name, condition, detail = '') {
  if (condition) {
    console.log(`  ✓ ${name}`);
    passed += 1;
  } else {
    console.error(`  ✗ ${name}${detail ? ` — ${detail}` : ''}`);
    failed += 1;
  }
}

async function run() {
  console.log(`\nEcoWatch API tests → ${BASE}\n`);

  // Health
  const health = await request('GET', '/health');
  assert('GET /health returns 200', health.status === 200);
  assert('Health status ok', health.data?.status === 'ok');

  // Public endpoints
  const contacts = await request('GET', '/v1/public/emergency-contacts');
  assert('GET /v1/public/emergency-contacts', contacts.status === 200);
  assert('Emergency contacts seeded', contacts.data?.length >= 3);

  const announcements = await request('GET', '/v1/public/announcements');
  assert('GET /v1/public/announcements', announcements.status === 200);

  const hotspots = await request('GET', '/v1/maps/hotspots');
  assert('GET /v1/maps/hotspots (public)', hotspots.status === 200);

  // Auth — municipal admin (municipality-wide)
  const login = await request('POST', '/v1/auth/login', {
    body: { email: 'municipal@ecowatch.gov', password: 'municipal123' },
  });
  assert('POST /v1/auth/login (municipal admin)', login.status === 200);
  authToken = login.data?.token;
  assert('Login returns JWT', typeof authToken === 'string' && authToken.length > 10);

  const badLogin = await request('POST', '/v1/auth/login', {
    body: { email: 'municipal@ecowatch.gov', password: 'wrong' },
  });
  assert('Bad login returns 401', badLogin.status === 401);

  // Submit report (anonymous)
  const report = await request('POST', '/v1/reports', {
    multipart: true,
    body: new URLSearchParams({
      category: 'water_pollution',
      description: 'API test — oily sheen on river near Tarkwa',
      latitude: '5.3025',
      longitude: '-1.9920',
      communityName: 'Tarkwa',
      source: 'app',
      isAnonymous: 'true',
      waterBodyNearby: 'true',
    }),
  });
  assert('POST /v1/reports creates report', report.status === 201);
  const token = report.data?.trackingToken;
  assert('Report has tracking token', token?.startsWith('EW-'));
  assert('Citizen status is submitted', report.data?.status === 'submitted');

  // Track report
  const trackInitial = await request('GET', `/v1/reports/track/${token}`);
  assert('GET /v1/reports/track/:token', trackInitial.status === 200);
  assert('Tracked report matches token', trackInitial.data?.trackingToken === token);
  assert('Track shows submitted', trackInitial.data?.status === 'submitted');

  const badTrack = await request('GET', '/v1/reports/track/EW-0000-0000');
  assert('Invalid token returns 404', badTrack.status === 404);

  // Authenticated list
  const list = await request('GET', '/v1/reports', { token: authToken });
  assert('GET /v1/reports (auth)', list.status === 200);
  assert('Reports list is array', Array.isArray(list.data));
  const adminRow = list.data?.find((r) => r.id === report.data?.id);
  assert('Admin list shows received', adminRow?.status === 'received' || adminRow?.status === 'underReview');

  const skipResolved = await request('PATCH', `/v1/reports/${report.data?.id}/status`, {
    token: authToken,
    body: { status: 'resolved', message: 'Should fail' },
  });
  assert('Municipal admin cannot update investigation status', skipResolved.status === 403);

  const researcherLogin = await request('POST', '/v1/auth/login', {
    body: { email: 'researcher@ecowatch.gov', password: 'researcher123' },
  });
  assert('Researcher login', researcherLogin.status === 200);
  const researcherToken = researcherLogin.data?.token;
  const researcherList = await request('GET', '/v1/reports', { token: researcherToken });
  assert('Researcher list is anonymized', researcherList.data?.[0]?.anonymized === true
    || researcherList.data?.every((r) => r.trackingToken == null));

  const agencyLogin = await request('POST', '/v1/auth/login', {
    body: { email: 'wrc@ecowatch.gov', password: 'wrc123' },
  });
  assert('Agency admin login (WRC)', agencyLogin.status === 200);
  const agencyToken = agencyLogin.data?.token;

  const agencyBlocked = await request('PATCH', `/v1/reports/${report.data?.id}/status`, {
    token: agencyToken,
    body: { status: 'underInvestigation', message: 'Agency should not update actions' },
  });
  assert('Agency admin cannot update investigation actions', agencyBlocked.status === 403);

  const officerLogin = await request('POST', '/v1/auth/login', {
    body: { email: 'wrc.officer@ecowatch.gov', password: 'wrcoff123' },
  });
  assert('Officer login (WRC)', officerLogin.status === 200);
  const officerToken = officerLogin.data?.token;
  const officerId = officerLogin.data?.user?.id;

  const reportId = report.data?.id;
  const assigned = await request('PATCH', `/v1/reports/${reportId}/assign`, {
    token: agencyToken,
    body: { officerId },
  });
  assert('Agency admin assigns officer', assigned.status === 200);

  // Officer advances investigation actions
  const steps = ['underInvestigation', 'siteVisited', 'awaitingAction', 'resolved'];
  let lastStatus = 'received';
  for (const step of steps) {
    const updated = await request('PATCH', `/v1/reports/${reportId}/status`, {
      token: officerToken,
      body: { status: step, message: `Officer update → ${step}` },
    });
    assert(`Officer status → ${step}`, updated.status === 200 && updated.data?.status === step);
    lastStatus = updated.data?.status;
  }
  assert('Officer reached resolved', lastStatus === 'resolved');

  const trackProgress = await request('GET', `/v1/reports/track/${token}`);
  assert('Citizen track shows completed', trackProgress.data?.status === 'completed');

  const closed = await request('PATCH', `/v1/reports/${reportId}/status`, {
    token: agencyToken,
    body: { status: 'closed', message: 'Agency closes completed case' },
  });
  assert('Agency admin closes resolved case', closed.status === 200 && closed.data?.status === 'closed');

  // Analytics
  const analytics = await request('GET', '/v1/analytics?period=weekly', {
    token: authToken,
  });
  assert('GET /v1/analytics', analytics.status === 200);
  assert('Analytics has totalReports', typeof analytics.data?.totalReports === 'number');

  // USSD webhook
  const ussd = await request('POST', '/v1/ussd/webhook', {
    body: { sessionId: 'test-1', phoneNumber: '+233000000000', text: '' },
  });
  assert('POST /v1/ussd/webhook', ussd.status === 200);

  console.log(`\nResults: ${passed} passed, ${failed} failed\n`);
  process.exit(failed > 0 ? 1 : 0);
}

run().catch((err) => {
  console.error('Test runner error:', err.message);
  console.error('Is the API running? npm.cmd run dev');
  process.exit(1);
});
