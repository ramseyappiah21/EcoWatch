const fs = require('fs');
const path = require('path');
const express = require('express');
const cors = require('cors');
const config = require('./config');

const reportsRouter = require('./routes/reports');
const authRouter = require('./routes/auth');
const mapsRouter = require('./routes/maps');
const analyticsRouter = require('./routes/analytics');
const ussdRouter = require('./routes/ussd');
const publicRouter = require('./routes/public');
const syncRouter = require('./routes/sync');
const adminPlatformRouter = require('./routes/adminPlatform');
const { getCategoryBySlug } = require('./services/categoryService');
const { runHotspotJob } = require('./jobs/hotspotJob');
const { pool } = require('./db/pool');

const app = express();

app.use(cors({ origin: config.corsOrigin }));
app.use(express.json({ limit: '2mb' }));
app.use(express.urlencoded({ extended: true }));

const uploadsPath = path.join(__dirname, '../uploads');
if (!fs.existsSync(uploadsPath)) fs.mkdirSync(uploadsPath, { recursive: true });
app.use('/uploads', express.static(uploadsPath));
app.use('/admin', express.static(path.join(__dirname, '../admin')));

// Android APK download (copy with: npm run apk:publish after flutter build apk)
const downloadsPath = path.join(__dirname, '../downloads');
if (!fs.existsSync(downloadsPath)) fs.mkdirSync(downloadsPath, { recursive: true });
app.use('/downloads', express.static(downloadsPath, {
  setHeaders: (res, filePath) => {
    if (filePath.endsWith('.apk')) {
      res.setHeader('Content-Type', 'application/vnd.android.package-archive');
      res.setHeader('Content-Disposition', 'attachment; filename="EcoWatch.apk"');
    }
  },
}));
app.get('/download/android', (_req, res) => {
  const apk =
    [path.join(downloadsPath, 'EcoWatch.apk'), path.join(downloadsPath, 'ecowatch.apk')]
      .find((p) => fs.existsSync(p));
  if (!apk) {
    return res.status(404).type('text/plain').send(
      'APK not ready. Run: flutter build apk --release && copy to backend/downloads/EcoWatch.apk',
    );
  }
  res.download(apk, 'EcoWatch.apk');
});

app.get('/health', async (_req, res) => {
  let database = 'ok';
  try {
    await pool.query('SELECT 1');
  } catch {
    database = 'unavailable';
  }
  const ok = database === 'ok';
  res.status(ok ? 200 : 503).json({
    status: ok ? 'ok' : 'degraded',
    service: 'ecowatch-api',
    version: '1.0.0',
    database,
  });
});

app.use('/v1/reports', reportsRouter);
app.use('/v1/auth', authRouter);
app.use('/v1/maps', mapsRouter);
app.use('/v1/analytics', analyticsRouter);
app.use('/v1/ussd', ussdRouter);
app.use('/v1/public', publicRouter);
app.use('/v1/sync', syncRouter);
app.use('/v1/admin', adminPlatformRouter);

/** Legacy officer URLs — same unified login portal */
app.get('/admin/officer/:slug', (req, res) => {
  if (!getCategoryBySlug(req.params.slug)) {
    return res.status(404).send('Unknown incident category');
  }
  res.redirect('/admin');
});

// Citizen Flutter web (optional): backend/public/web or repo build/web
const webAppPath = [
  path.join(__dirname, '../public/web'),
  path.join(__dirname, '../../build/web'),
].find((p) => fs.existsSync(path.join(p, 'index.html')));

if (webAppPath) {
  app.use(express.static(webAppPath));
  app.get('*', (req, res, next) => {
    if (
      req.path.startsWith('/v1') ||
      req.path.startsWith('/admin') ||
      req.path.startsWith('/uploads') ||
      req.path.startsWith('/health') ||
      req.path.startsWith('/downloads') ||
      req.path.startsWith('/download')
    ) {
      return next();
    }
    if (req.method !== 'GET' && req.method !== 'HEAD') return next();
    res.sendFile(path.join(webAppPath, 'index.html'), (err) => {
      if (err) next();
    });
  });
} else {
  app.get('/', (_req, res) => res.redirect('/admin'));
}

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(config.port, () => {
  console.log(`EcoWatch API listening on http://localhost:${config.port}`);
  // Hotspot detection every 6 hours
  runHotspotJob().catch(console.error);
  setInterval(() => runHotspotJob().catch(console.error), 6 * 60 * 60 * 1000);
});
