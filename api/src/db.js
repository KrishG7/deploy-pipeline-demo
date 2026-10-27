import pg from 'pg';

// Connection settings come from the standard PG* variables (PGHOST, PGUSER, ...)
// or a single DATABASE_URL. Nothing is hard-coded here.
export const pool = new pg.Pool(
  process.env.DATABASE_URL
    ? { connectionString: process.env.DATABASE_URL }
    : {},
);

pool.on('error', (err) => {
  // An idle client lost its connection (for example the database restarted).
  // The pool replaces it on the next query, so log and carry on.
  console.error('postgres pool error:', err.message);
});
