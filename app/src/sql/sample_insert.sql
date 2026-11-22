INSERT INTO samples 
  (path, name, ext, duration_ms, lufs, true_peak, rms, width, centroid) 
VALUES 
  (?, ?, ?, ?, ?, ?, ?, ?, ?) 
ON CONFLICT DO NOTHING;
