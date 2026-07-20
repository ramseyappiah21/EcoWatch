const express = require('express');
const fs = require('fs');
const path = require('path');
const { pool } = require('../db/pool');
const { uploadDir } = require('../services/mediaService');

const router = express.Router();

/**
 * GET /v1/media/:id — public evidence bytes (needed for <img> tags).
 * Prefers Postgres file_data (survives Render redeploys); falls back to local disk.
 */
router.get('/:id', async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT id, storage_url, mime_type, file_data
       FROM report_media
       WHERE id = $1`,
      [req.params.id],
    );
    if (!rows.length) {
      return res.status(404).json({ error: 'Media not found' });
    }

    const row = rows[0];
    const mime = row.mime_type || 'application/octet-stream';

    if (row.file_data && row.file_data.length) {
      res.setHeader('Content-Type', mime);
      res.setHeader('Cache-Control', 'public, max-age=86400');
      return res.send(row.file_data);
    }

    // Legacy rows: try local disk from storage_url filename
    const filename = (row.storage_url || '').split('/').pop();
    if (filename) {
      const filePath = path.join(uploadDir, filename);
      if (fs.existsSync(filePath)) {
        res.setHeader('Content-Type', mime);
        res.setHeader('Cache-Control', 'public, max-age=86400');
        return res.sendFile(filePath);
      }
    }

    return res.status(404).json({
      error: 'Evidence file missing',
      hint: 'File was lost from ephemeral disk. Re-submit the report or re-seed evidence after this update.',
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to load media' });
  }
});

module.exports = router;
