const config = require('../config');

const STATUS_LABELS = {
  inProgress: 'In Progress',
  resolved: 'Completed',
};

function normalizePhone(phone) {
  if (!phone) return null;
  let p = String(phone).replace(/\s/g, '');
  if (p.startsWith('0')) p = `+233${p.slice(1)}`;
  if (!p.startsWith('+')) p = `+${p}`;
  return p;
}

function isSmsConfigured() {
  return (
    config.africaTalking.smsEnabled &&
    Boolean(config.africaTalking.apiKey && config.africaTalking.username)
  );
}

function apiBaseUrl() {
  return config.africaTalking.username === 'sandbox'
    ? 'https://api.sandbox.africastalking.com'
    : 'https://api.africastalking.com';
}

/**
 * Send SMS via Africa's Talking. Resolves when the API accepts the message.
 * In sandbox, the recipient must be a verified test number on your AT dashboard.
 */
async function sendSms(to, message) {
  const phone = normalizePhone(to);
  if (!phone) {
    console.warn('[sms] skipped — no phone number');
    return null;
  }
  if (!isSmsConfigured()) {
    console.warn('[sms] skipped — AT_API_KEY / AT_USERNAME not configured');
    return null;
  }

  const params = new URLSearchParams({
    username: config.africaTalking.username,
    to: phone,
    message,
  });
  if (config.africaTalking.smsSender) {
    params.set('from', config.africaTalking.smsSender);
  }

  const response = await fetch(`${apiBaseUrl()}/version1/messaging`, {
    method: 'POST',
    headers: {
      apiKey: config.africaTalking.apiKey,
      Accept: 'application/json',
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: params,
  });

  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    const detail = body?.SMSMessageData?.Message || body?.errorMessage || response.statusText;
    throw new Error(`SMS API error: ${detail}`);
  }

  const recipients = body?.SMSMessageData?.Recipients || [];
  const failed = recipients.find((r) => Number(r.statusCode) !== 101);
  if (failed) {
    throw new Error(`SMS delivery failed: ${failed.status || failed.number}`);
  }

  console.log(`[sms] sent to ${phone}`);
  return body;
}

function sendSmsSafe(to, message) {
  return sendSms(to, message).catch((err) => {
    console.error('[sms]', err.message);
    return null;
  });
}

function tokenSubmittedMessage(trackingToken) {
  const shortCode = config.africaTalking.shortCode;
  return (
    `EcoWatch Tarkwa: Your report token is ${trackingToken}. ` +
    `Dial ${shortCode}, choose Track Report, and enter this token to follow progress.`
  );
}

function statusUpdateMessage(trackingToken, status) {
  const label = STATUS_LABELS[status] || status;
  const shortCode = config.africaTalking.shortCode;
  if (status === 'resolved') {
    return (
      `EcoWatch: Report ${trackingToken} is Completed. ` +
      'Thank you for helping protect our environment.'
    );
  }
  return (
    `EcoWatch: Report ${trackingToken} is now ${label}. ` +
    `Dial ${shortCode} and choose Track Report to see updates.`
  );
}

module.exports = {
  normalizePhone,
  sendSms,
  sendSmsSafe,
  tokenSubmittedMessage,
  statusUpdateMessage,
  isSmsConfigured,
};
