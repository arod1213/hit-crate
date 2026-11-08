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

CREATE VIRTUAL TABLE IF NOT EXISTS samples_fts USING fts5(
  name,
  content=samples,
  content_rowid=rowid,
  tokenize='trigram'
);

INSERT INTO samples_fts(rowid, name)
  SELECT path, name FROM samples;

CREATE TRIGGER IF NOT EXISTS samples_fts_insert AFTER INSERT ON samples BEGIN
INSERT INTO samples_fts(rowid, name) VALUES (new.rowid, new.name);
        END;

CREATE TRIGGER IF NOT EXISTS samples_fts_delete AFTER DELETE ON samples BEGIN
  INSERT INTO samples_fts(samples_fts, rowid, name) VALUES ('delete', old.rowid, old.name);
END;

CREATE TRIGGER IF NOT EXISTS samples_fts_update
AFTER UPDATE OF name ON samples
BEGIN
INSERT INTO samples_fts(samples_fts, rowid, name)
          VALUES ('delete', old.rowid, old.name);

INSERT INTO samples_fts(rowid, name)
          VALUES (new.rowid, new.name);
        END;
