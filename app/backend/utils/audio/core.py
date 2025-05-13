import numpy as np
from typing import Tuple
import librosa
from pathlib import Path
from app.backend.models import AudioFormat


# audio operations
def load_audio(path: str) -> Tuple[np.ndarray, int | float]:
    audio, sr = librosa.load(path, mono=True, res_type="soxr_lq")
    return (audio, sr)


def normalize_audio(audio: np.ndarray, floor_db: float = -45):
    floor_amp = db_to_amp(floor_db)
    # print(np.abs(audio))
    # print(f"min is {np.min(np.abs(audio))}")
    gated_audio = audio[np.abs(audio) > floor_amp]

    if len(gated_audio) != 0:
        audio = gated_audio

    peak = np.max(audio)
    # print(f"min is {np.min(np.abs(audio))}")
    if peak == 0:
        return audio

    mult = 1 / peak
    return audio * mult


# array operations
def pad_audio(audio: np.ndarray):
    if len(audio) < 2048:
        audio = np.pad(audio, (0, 2048 - len(audio)), mode="constant")
    return audio


def filter_frequency_data(arr: np.ndarray, floor: float = 25.0):
    arr = arr[~np.isnan(arr) & (arr != 0)]
    return arr[arr > floor]


def filter_nan(arr):
    return arr[~np.isnan(arr) & (arr != 0)]


def filter_below(arr, thresh: float):
    return arr[arr > thresh]


def get_median(arr: np.ndarray, floor: float) -> float:
    arr = filter_nan(arr)
    if np.max(arr) > 20:
        arr = filter_below(arr, floor)
        if len(arr) == 0:
            raise ValueError(
                "File is likely silent, median could not be calculated"
            )

    if len(arr) == 0:
        raise ValueError(
            "File is likely silent, median could not be calculated"
        )

    median = np.median(arr)
    if median < 20:
        median = np.max(arr)
    return float(median)


# metadata
def get_file_format(path: Path) -> AudioFormat | None:
    supported_formats = {fmt.value for fmt in AudioFormat}
    suffix = path.suffix.lower()
    if suffix not in supported_formats:
        return None
    return AudioFormat(suffix)


# utility
def amp_to_db(amplitude, reference=1.0):
    """
    Convert amplitude to decibels (dB)

    Parameters:
    amplitude : float or numpy array
        The amplitude value(s) to convert
    reference : float, optional
        Reference amplitude (default: 1.0)

    Returns:
    float or numpy array
        The amplitude in dB
    """
    # Avoid log of zero or negative values
    with np.errstate(divide="ignore", invalid="ignore"):
        # Formula: dB = 20 * log10(amplitude/reference)
        db = 20 * np.log10(np.abs(amplitude) / reference)

        # Replace -inf (result of log10(0)) with very low dB
        if isinstance(db, np.ndarray):
            db = np.where(np.isinf(db), -120.0, db)
        elif np.isinf(db):
            db = -120.0

    return db


def db_to_amp(db, reference=1.0):
    """
    Convert decibels (dB) to amplitude

    Parameters:
    db : float or numpy array
        The decibel value(s) to convert
    reference : float, optional
        Reference amplitude (default: 1.0)

    Returns:
    float or numpy array
        The amplitude value(s)
    """
    # Formula: amplitude = reference * 10^(dB/20)
    return reference * (10 ** (db / 20.0))
