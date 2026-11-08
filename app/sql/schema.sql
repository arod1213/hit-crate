CREATE TABLE samples (
  path TEXT PRIMARY KEY NOT NULL,
  name TEXT NOT NULL,
  ext TEXT,
  lufs REAL,
  true_peak REAL,
  rms REAL NOT NULL,
  width REAL NOT NULL DEFAULT 0.0,
  centroid REAL,
  duration_ms INTEGER NOT NULL
);
