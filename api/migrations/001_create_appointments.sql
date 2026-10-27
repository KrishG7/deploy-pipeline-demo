CREATE TABLE appointments (
  id           serial PRIMARY KEY,
  patient_name text        NOT NULL CHECK (length(patient_name) BETWEEN 1 AND 120),
  service      text        NOT NULL CHECK (length(service) BETWEEN 1 AND 80),
  starts_at    timestamptz NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX appointments_starts_at_idx ON appointments (starts_at);
