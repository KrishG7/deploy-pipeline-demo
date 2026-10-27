import express from 'express';
import { pool } from './db.js';

export const version = process.env.APP_VERSION || 'dev';
const environment = process.env.APP_ENV || 'local';

export function createApp() {
  const app = express();
  app.disable('x-powered-by');
  app.use(express.json({ limit: '10kb' }));

  app.get('/health', async (_req, res) => {
    const started = Date.now();
    try {
      await pool.query('SELECT 1');
      res.json({
        status: 'ok',
        version,
        environment,
        database: { status: 'ok', latencyMs: Date.now() - started },
      });
    } catch (err) {
      res.status(503).json({
        status: 'degraded',
        version,
        environment,
        database: { status: 'error', error: err.code || err.message },
      });
    }
  });

  app.get('/api/appointments', async (_req, res, next) => {
    try {
      const { rows } = await pool.query(
        `SELECT id, patient_name, service, starts_at, created_at
           FROM appointments
          ORDER BY starts_at, id`,
      );
      res.json(rows);
    } catch (err) {
      next(err);
    }
  });

  app.post('/api/appointments', async (req, res, next) => {
    const { patient_name: patientName, service, starts_at: startsAt } = req.body || {};
    const errors = [];
    if (typeof patientName !== 'string' || !patientName.trim() || patientName.length > 120) {
      errors.push('patient_name is required (max 120 characters)');
    }
    if (typeof service !== 'string' || !service.trim() || service.length > 80) {
      errors.push('service is required (max 80 characters)');
    }
    if (typeof startsAt !== 'string' || Number.isNaN(Date.parse(startsAt))) {
      errors.push('starts_at must be an ISO 8601 date-time');
    }
    if (errors.length) {
      return res.status(400).json({ errors });
    }
    try {
      const { rows } = await pool.query(
        `INSERT INTO appointments (patient_name, service, starts_at)
         VALUES ($1, $2, $3)
         RETURNING id, patient_name, service, starts_at, created_at`,
        [patientName.trim(), service.trim(), new Date(startsAt).toISOString()],
      );
      res.status(201).json(rows[0]);
    } catch (err) {
      next(err);
    }
  });

  // eslint-disable-next-line no-unused-vars
  app.use((err, _req, res, _next) => {
    console.error(err);
    res.status(500).json({ error: 'internal error' });
  });

  return app;
}
