// Inserts 25 fictional appointments, but only into an empty table, so it is
// safe to run on every container start. Set SEED_ON_START=false to skip.
import { pool } from './db.js';

const names = ['A. Patel', 'B. Okafor', 'C. Silva', 'D. Novak', 'E. Tanaka'];
const services = ['Check-up', 'Cleaning', 'Consultation', 'Follow-up', 'X-ray'];

export async function seed() {
  const { rows } = await pool.query('SELECT count(*)::int AS n FROM appointments');
  if (rows[0].n > 0) {
    console.log(`seed skipped: ${rows[0].n} rows already present`);
    return 0;
  }
  const base = Date.UTC(2026, 10, 2, 9, 0, 0); // 2 Nov 2026, 09:00 UTC
  const values = [];
  const params = [];
  for (let i = 0; i < 25; i++) {
    const day = Math.floor(i / 5);
    const slot = i % 5;
    params.push(
      `Patient ${names[i % names.length]} #${i + 1}`,
      services[(i * 3) % services.length],
      new Date(base + day * 86_400_000 + slot * 3_600_000).toISOString(),
    );
    values.push(`($${i * 3 + 1}, $${i * 3 + 2}, $${i * 3 + 3})`);
  }
  await pool.query(
    `INSERT INTO appointments (patient_name, service, starts_at) VALUES ${values.join(', ')}`,
    params,
  );
  console.log('seed inserted 25 rows');
  return 25;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  if (process.env.SEED_ON_START === 'false') {
    console.log('seed disabled (SEED_ON_START=false)');
  } else {
    seed()
      .then(() => pool.end())
      .catch((err) => {
        console.error('seed failed:', err.message);
        process.exit(1);
      });
  }
}
