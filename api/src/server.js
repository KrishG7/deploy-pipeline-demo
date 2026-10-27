import { createApp, version } from './app.js';
import { pool } from './db.js';

const port = Number(process.env.PORT || 3000);
const server = createApp().listen(port, () => {
  console.log(`api ${version} listening on ${port}`);
});

// Graceful shutdown so `docker compose up -d` swaps containers without
// cutting requests mid-flight.
function shutdown(signal) {
  console.log(`${signal} received, shutting down`);
  server.close(() => pool.end().finally(() => process.exit(0)));
  setTimeout(() => process.exit(1), 10_000).unref();
}
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
