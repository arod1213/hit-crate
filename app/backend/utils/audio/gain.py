import numpy as np
import pyloudnorm as pyln


def get_lufs(audio: np.ndarray, sr: int | float, min_duration=0.5) -> float:
    target_len = int(min_duration * sr)
    audio = audio - np.mean(audio, axis=0)  # remove DC offset

    padded = audio
    if len(audio) < target_len:
        padded = np.pad(audio, (0, target_len - len(audio)), "constant")

    meter = pyln.Meter(sr)  # defaults to K-weighting
    lufs = meter.integrated_loudness(padded)
    return lufs


