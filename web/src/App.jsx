/* global __APP_VERSION__ */
import { useEffect, useState } from 'react';

const dateFormat = new Intl.DateTimeFormat('en-GB', {
  weekday: 'short',
  day: 'numeric',
  month: 'short',
  hour: '2-digit',
  minute: '2-digit',
  timeZone: 'UTC',
});

export default function App() {
  const [appointments, setAppointments] = useState(null);
  const [environment, setEnvironment] = useState('');
  const [error, setError] = useState('');

  useEffect(() => {
    fetch('/api/appointments')
      .then((res) => (res.ok ? res.json() : Promise.reject(new Error(`HTTP ${res.status}`))))
      .then(setAppointments)
      .catch((err) => setError(err.message));
    fetch('/health')
      .then((res) => res.json())
      .then((body) => setEnvironment(body.environment || ''))
      .catch(() => {});
  }, []);

  return (
    <div className="page">
      <header>
        <h1>Appointments</h1>
        {environment && <span className="env">{environment}</span>}
      </header>
      <main>
        {error && <p className="error">Could not load appointments: {error}</p>}
        {!appointments && !error && <p>Loading...</p>}
        {appointments && (
          <table>
            <caption>{appointments.length} upcoming appointments</caption>
            <thead>
              <tr>
                <th scope="col">#</th>
                <th scope="col">Patient</th>
                <th scope="col">Service</th>
                <th scope="col">Time (UTC)</th>
              </tr>
            </thead>
            <tbody>
              {appointments.map((a) => (
                <tr key={a.id}>
                  <td>{a.id}</td>
                  <td>{a.patient_name}</td>
                  <td>{a.service}</td>
                  <td>{dateFormat.format(new Date(a.starts_at))}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </main>
      <footer>Appointment scheduler v{__APP_VERSION__}. New in 1.1: bookings open 7 days a week.</footer>
    </div>
  );
}
