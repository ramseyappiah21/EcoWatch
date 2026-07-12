const express = require('express');

const router = express.Router();

/** POST /v1/sync/batch — offline metadata batch (media uploaded per report) */
router.post('/batch', async (req, res) => {
  const reports = req.body?.reports || [];
  const results = reports.map((item) => ({
    clientId: item.clientId,
    status: 'queued',
    message: 'Use POST /v1/reports for full submission with media',
  }));
  res.json({ synced: results.length, results });
});

module.exports = router;
