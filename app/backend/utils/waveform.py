from pathlib import Path
from typing import Optional

import numpy as np
import soundfile as sf


def get_waveform_data(path: Path) -> np.ndarray:
    try:
        with sf.SoundFile(str(path), "r") as f:
            waveform = f.read(dtype="float32")
            if f.channels > 1:
                waveform = np.mean(waveform, axis=1)
            return waveform
    except sf.SoundFileError:
        return np.empty((0,))


def downsample_waveform(waveform: np.ndarray, max_points: int = 1000) -> np.ndarray:
    length = len(waveform)
    if length <= max_points:
        return waveform
    else:
        waveform = waveform[: length - (length % max_points)]
        return waveform.reshape(max_points, -1).mean(axis=1)


def render_waveform(path: Path) -> Optional[np.ndarray]:
    waveform = get_waveform_data(path)
    if waveform.size == 0:
        return np.empty((0,))

    waveform = downsample_waveform(waveform)

    # normalize to peak of (1, -1)
    peak = np.max(np.abs(waveform))
    if peak > 0:
        waveform = waveform / peak

    if waveform.size == 0:
        return None

    window_size = 5
    waveform = np.convolve(
        waveform, np.ones(window_size) / window_size, mode="same"
    )
    waveform = np.clip(waveform, -1, 1)

    return waveform
