from pathlib import Path

import numpy as np
from app.backend.utils.audio.get_details import AudioDetail

FILE_A = Path.home() / "Desktop" / "Scan Test" / "1sec.wav"
FILE_B = Path.home() / "Desktop" / "Scan Test" / "2sec.wav"
FILE_C = Path.home() / "Desktop" / "Scan Test" / "3sec.wav"


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


SAMPLE_FOLDER = Path.home() / "Documents" / "Sample Libraries" / "M-Phazes Drums and Samples" / "_!Beat Butcha Kits"


# @benchmark
# def scan():
    # with Session(engine) as session:
    #     DirectoryService(session).create(SAMPLE_FOLDER)
    # with Session(engine) as session:
    #     DirectoryService(session).rescan(SAMPLE_FOLDER)
#
# def delete():
#     pass
#     with Session(engine) as session:
#         DirectoryService(session).delete(str(SAMPLE_FOLDER))
# scan()
# delete()



files = [FILE_A, FILE_B, FILE_C]
for f in files:
    AudioDetail(f)
    # audio, sr = load_audio(str(f))
    # print(len(audio), sr)
    # detail = AudioDetail(f)
    # meta = AudioMeta(f)
