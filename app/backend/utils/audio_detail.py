from pathlib import Path
from typing import Tuple

import librosa
import numpy as np
import soundfile as sf

from app.backend.utils.audio.gain import get_lufs

from .audio.freq import rolloff, spectral_centroid, mfcc
from .audio.width import get_stereo_width
from .audio.core import normalize_audio, filter_frequency_data, pad_audio

class AudioDetail:
    def __init__(self, path: Path):
        self.name: str = path.stem
        audio, sr = load_audio(str(path))

        audio = pad_audio(audio)

        self.lufs: float = get_lufs(audio, sr)
        self.mfcc = mfcc(audio, sr)

        info = sf.info(str(path))
        if info.channels > 2:
            raise ValueError("Invalid audio format")
        elif info.channels == 1:
            self.stereo_width = 0
        else:
            self.stereo_width = get_stereo_width(str(path))


        normalized_audio = normalize_audio(audio, floor_db=-35)
        normalized_audio = pad_audio(normalized_audio)
        if len(normalized_audio) == 0:
            raise ValueError(
                "Invalid audio: likely silent even after normalization"
                             )
        
        mel_spec = librosa.feature.melspectrogram(y=normalized_audio, sr=sr)
        S = spectral_centroid(mel_spec)
        S_filtered = filter_frequency_data(S)
        if len(S_filtered) != 0:
            S = S_filtered
        self.spectral_centroid = get_median(S, floor=20)

        R = rolloff(normalized_audio, sr)
        R_filtered = filter_frequency_data(R)
        if len(R_filtered) != 0:
            R = R_filtered
        R_max_values = np.sort(R)[-3:]
        self.rolloff = np.median(R_max_values)


def load_audio(path: str) -> Tuple[np.ndarray, int | float]:
    audio, sr = librosa.load(path, mono=True, res_type="soxr_lq")
    return (audio, sr)


def filter_nan(arr):
    return arr[~np.isnan(arr) & (arr != 0)]


def filter_below(arr, thresh: float):
    return arr[arr > thresh]


def get_median(arr: np.ndarray, floor: float):
    arr = filter_nan(arr)
    if np.max(arr) > 20:
        arr = filter_below(arr, floor)
        if len(arr) == 0:
            raise ValueError(
                "File is likely silent, median could not be calculated"
            )

    median = np.median(arr)
    if median < 20:
        median = np.max(arr)
    return median
