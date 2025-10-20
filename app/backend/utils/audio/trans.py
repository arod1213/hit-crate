from typing import Tuple
import librosa
import numpy as np


def onset_strength(audio: np.ndarray, sr: int | float) -> Tuple[np.float32, np.float32]:
    res = librosa.onset.onset_strength(y=audio, sr=sr)

    diff = np.diff(res)
    onset_idx = np.argmax(diff)
    decay_idx = np.argmin(diff)

    onset_max: np.float32 = diff[onset_idx]
    next_val: np.float32 = diff[onset_idx + 1]
    decay_max = next_val if next_val is not None else diff[decay_idx]

    return onset_max, decay_max
