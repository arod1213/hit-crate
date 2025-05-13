import librosa
import numpy as np
from pathlib import Path
from app.backend.utils.audio.freq import spectral_centroid, rolloff

FILE_A = Path.home() / "Desktop" / "Scan Test" / "bright3.wav"
FILE_B = Path.home() / "Desktop" / "Scan Test" / "dark2.wav"


def filter_nan(arr):
    return arr[~np.isnan(arr) & (arr != 0)]


def filter_below(arr, thresh: float):
    return arr[arr > thresh]


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


def normalize_audio(audio: np.ndarray, floor_db: float = -35):
    floor_amp = db_to_amp(floor_db)
    # print(np.abs(audio))
    # print(f"min is {np.min(np.abs(audio))}")
    audio = audio[np.abs(audio) > floor_amp]

    peak = np.max(audio)
    # print(f"min is {np.min(np.abs(audio))}")
    if peak == 0:
        return audio
    mult = 1 / peak
    return audio * mult


def smart_filter(arr: np.ndarray):
    arr = filter_nan(arr)
    # mean = np.mean(arr)
    # std_dev = np.std(arr)
    # # print(f"mean is {mean}")
    # # print(f"std_dev is {std_dev}")
    #
    # z_scores = (arr - mean) / std_dev
    # mask = np.abs(z_scores) <= 0.7
    return arr[arr > 25]


files = [FILE_A, FILE_B]
for f in files:
    y, sr = librosa.load(f, mono=True, res_type="soxr_lq")
    y = normalize_audio(y)
    S = librosa.feature.melspectrogram(y=y, sr=sr)
    centroid = spectral_centroid(S)
    roll = rolloff(y, sr)

    centroid = smart_filter(centroid)
    roll = smart_filter(roll)
    # print(f"roll is {roll}")
    # print(f"roll max is {np.max(roll)}")
    roll = np.sort(roll)[-3:]

    value = centroid
    print(f"{f.name} PROPERTIES")
    print(f"centroid is {centroid}")
    print(f"rolloff is {roll}")
    # print(f"Mean: {np.mean(roll):.2f} - {np.mean(centroid):.2f}")
    # print(f"Median: {np.median(roll):.2f} - {np.median(centroid):.2f}")
    # print(f"Stdev: {np.std(roll):.2f} - {np.std(centroid):.2f}")
