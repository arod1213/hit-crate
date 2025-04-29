from pathlib import Path

import numpy as np
import soundfile as sf


def get_waveform_data(path: Path) -> np.ndarray:
    try:
        with sf.SoundFile(str(path), "r") as f:
            waveform = f.read(dtype="float32")  # shape: (n_frames, n_channels)
            if f.channels > 1:
                # Convert to mono by averaging channels
                waveform = np.mean(waveform, axis=1)
            return waveform
    except sf.SoundFileError:
        return np.empty((0,))


def downsample_waveform(
    waveform: np.ndarray, max_points: int = 1000
) -> np.ndarray:
    """Downsample waveform to a fixed number of points for plotting."""
    length = len(waveform)
    if length <= max_points:
        return waveform
    else:
        # Chunk averaging
        waveform = waveform[: length - (length % max_points)]
        return waveform.reshape(max_points, -1).mean(axis=1)


def render_waveform(path: Path) -> np.ndarray:
    waveform = get_waveform_data(path)
    if waveform.size == 0:
        return np.empty((0,))

    # Downsample the waveform to a fixed number of points
    waveform = downsample_waveform(waveform)

    # Maximizing waveform to -1 to 1
    peak = np.max(np.abs(waveform))
    if peak > 0:
        waveform = (
            waveform / peak
        )  # Normalize by peak, ensuring full span from -1 to 1

    return waveform
