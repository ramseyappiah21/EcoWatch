const express = require('express');
const { pool } = require('../db/pool');
const { generateTrackingToken, hashPhone } = require('../services/tokenService');
const { routeReportToAdmins } = require('../services/reportRoutingService');
const { normalizePhone, sendSmsSafe, tokenSubmittedMessage } = require('../services/smsService');
const { INCIDENT_CATEGORIES } = require('../services/categoryService');
const { citizenStatusLabel } = require('../services/statusService');
const config = require('../config');

const router = express.Router();
const BACK_HINT = '\n0.Back';

function withBackHint(menu, showBack = true) {
  return showBack ? `${menu}${BACK_HINT}` : menu;
}

function normalizeNavigation(parts) {
  const result = [];
  for (const part of parts) {
    if (part === '0') {
      if (result.length > 0) result.pop();
      continue;
    }
    result.push(part);
  }
  return result;
}

function categoryByMenuIndex(menuIndex) {
  return INCIDENT_CATEGORIES[Number(menuIndex) - 1];
}

function buildMainCategoryMenu() {
  const lines = INCIDENT_CATEGORIES.map((c, i) => `${i + 1}.${c.label}`);
  return withBackHint(`Select incident type:\n${lines.join('\n')}`);
}

function resolveReport(selections) {
  const category = categoryByMenuIndex(selections[1]);
  const community = selections[2]?.trim() || 'Tarkwa';
  const label = category?.label || 'Incident';

  return {
    category: category?.key || 'wasteDumping',
    description: '',
    community,
  };
}

function welcomeMenu() {
  return withBackHint(
    'Welcome to EcoWatch Tarkwa\n1. Report Incident\n2. Track Report\n3. Privacy Information\n4. Help',
    false,
  );
}

function renderUssd(selections) {
  const level = selections.length;
  const flow = selections[0];

  if (level === 0) {
    return { message: welcomeMenu(), endSession: false };
  }

  if (level === 1) {
    if (flow === '1') {
      return { message: buildMainCategoryMenu(), endSession: false };
    }
    if (flow === '2') {
      return {
        message: withBackHint('Enter tracking token (EW-XXXX-XXXX):'),
        endSession: false,
      };
    }
    if (flow === '3') {
      return {
        message:
          'We never store IMEI, device IDs, or IP. Only your tracking token is saved.',
        endSession: true,
      };
    }
    return {
      message: `EcoWatch Tarkwa. Dial ${config.africaTalking.shortCode} anytime. EPA: 0302-664697`,
      endSession: true,
    };
  }

  if (flow === '2' && level >= 2) {
    return {
      token: selections[1]?.toUpperCase(),
      trackLookup: true,
    };
  }

  if (flow === '1') {
    if (level === 2) {
      return {
        message: withBackHint('Enter community name:'),
        endSession: false,
      };
    }
    if (level >= 3) {
      return { submitReport: true };
    }
  }

  return { message: 'Invalid option. Dial again to start.', endSession: true };
}

// AT may probe the callback URL with GET when saving settings.
router.get('/webhook', (_req, res) => {
  res.type('text/plain').send('EcoWatch USSD webhook is running');
});

router.post('/webhook', async (req, res) => {
  console.log('[ussd] incoming', {
    sessionId: req.body?.sessionId,
    phoneNumber: req.body?.phoneNumber,
    serviceCode: req.body?.serviceCode,
    text: req.body?.text,
  });

  const { sessionId, phoneNumber, text = '' } = req.body;
  const rawParts = text ? text.split('*') : [];
  const selections = normalizeNavigation(rawParts);

  let message;
  let endSession = false;

  try {
    const step = renderUssd(selections);

    if (step.trackLookup) {
      const { rows } = await pool.query(
        'SELECT status FROM reports WHERE tracking_token = $1',
        [step.token],
      );
      if (rows.length) {
        message = `Status: ${citizenStatusLabel(rows[0].status)}\nThank you.`;
        endSession = true;
      } else {
        message = withBackHint('Token not found. Try again.');
        endSession = false;
      }
    } else if (step.submitReport) {
      const token = generateTrackingToken();
      const { category, description, community } = resolveReport(selections);
      const reporterPhone = normalizePhone(phoneNumber);

      const inserted = await pool.query(
        `INSERT INTO reports (
          tracking_token, category, description, latitude, longitude,
          community_name, source, is_anonymous, severity, severity_score, reporter_phone,
          status
        ) VALUES ($1,$2,$3,$4,$5,$6,'ussd',TRUE,'low',0,$7,'received')
        RETURNING id, tracking_token, category, severity`,
        [token, category, description, 5.3018, -1.9931, community, reporterPhone],
      );

      const newReport = inserted.rows[0];

      await pool.query(
        `INSERT INTO report_status_history (report_id, status, message)
         VALUES ($1, 'received', 'Report received — under review')`,
        [newReport.id],
      );

      await routeReportToAdmins(pool, newReport);

      await pool.query(
        `INSERT INTO ussd_sessions (session_id, phone_hash, payload)
         VALUES ($1, $2, $3)`,
        [sessionId, hashPhone(phoneNumber || ''), JSON.stringify(req.body)],
      );

      if (reporterPhone) {
        sendSmsSafe(reporterPhone, tokenSubmittedMessage(token));
      }

      message = `Report submitted!\nToken: ${token}\nYou will also receive this token by SMS.`;
      endSession = true;
    } else {
      message = step.message;
      endSession = step.endSession;
    }
  } catch (err) {
    console.error('[ussd]', err);
    message = 'Sorry, something went wrong. Please try again later.';
    endSession = true;
  }

  res.set('Content-Type', 'text/plain');
  res.send(`${endSession ? 'END' : 'CON'} ${message}`);
});

module.exports = router;
