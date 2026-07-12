const crypto = require('crypto');

function generateTrackingToken() {
  const part = () => crypto.randomBytes(2).toString('hex').toUpperCase();
  return `EW-${part()}-${part()}`;
}

function hashPhone(phone) {
  return crypto.createHash('sha256').update(phone).digest('hex');
}

module.exports = { generateTrackingToken, hashPhone };
