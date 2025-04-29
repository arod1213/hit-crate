import numpy as np


def get_rms(audio: np.ndarray) -> float:
    # RMS calculation
    rms = np.sqrt(np.mean(audio**2))
    return rms
