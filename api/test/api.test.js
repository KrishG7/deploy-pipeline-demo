// Integration tests. They need a real PostgreSQL (CI starts one as a service
// container) reachable through the standard PG* environment variables.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { createApp } from '../src/app.js';
import { migrate } from '../src/migrate.js';
import { seed } from '../src/seed.js';
import { pool } from '../src/db.js';

const app = createApp();

before(async () => {
  await pool.query('DROP TABLE IF EXISTS appointments, schema_migrations');
  await migrate();
});

after(async () => {
  await pool.end();
});

test('migration is idempotent', async () => {
  await migrate();
  const { rows } = await pool.query('SELECT name FROM schema_migrations');
  assert.deepEqual(rows.map((r) => r.name), ['001_create_appointments.sql']);
});

test('seed inserts 25 rows once', async () => {
  assert.equal(await seed(), 25);
  assert.equal(await seed(), 0);
  const { rows } = await pool.query('SELECT count(*)::int AS n FROM appointments');
  assert.equal(rows[0].n, 25);
});

test('GET /health reports status, version and database', async () => {
  const res = await request(app).get('/health').expect(200);
  assert.equal(res.body.status, 'ok');
  assert.equal(typeof res.body.version, 'string');
  assert.equal(res.body.database.status, 'ok');
});

test('GET /api/appointments lists the seeded rows', async () => {
  const res = await request(app).get('/api/appointments').expect(200);
  assert.equal(res.body.length, 25);
  assert.ok(res.body[0].patient_name);
});

test('POST /api/appointments creates a row', async () => {
  const res = await request(app)
    .post('/api/appointments')
    .send({ patient_name: 'Test Patient', service: 'Check-up', starts_at: '2026-12-01T10:00:00Z' })
    .expect(201);
  assert.equal(res.body.patient_name, 'Test Patient');
  const list = await request(app).get('/api/appointments').expect(200);
  assert.equal(list.body.length, 26);
});

test('POST /api/appointments rejects invalid input', async () => {
  const res = await request(app).post('/api/appointments').send({ service: '' }).expect(400);
  assert.equal(res.body.errors.length, 3);
});
