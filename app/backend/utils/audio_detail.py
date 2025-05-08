from pathlib import Path
from typing import Tuple

import librosa
import numpy as np
import soundfile as sf

from app.backend.utils.audio_gain import get_lufs

from .audio_freq import mfcc, rolloff, spectral_centroid
from .audio_width import get_stereo_width


def load_audio(path: str) -> Tuple[np.ndarray, int | float]:
    audio, sr = librosa.load(path, mono=True, res_type="soxr_lq")
    return (audio, sr)


def filter_nan(arr):
    return arr[~np.isnan(arr) & (arr != 0)]


class AudioDetail:
    def __init__(self, path: Path):
        audio, sr = load_audio(str(path))

        if len(audio) < 2048:
            audio = np.pad(audio, (0, 2048 - len(audio)), mode="constant")

        info = sf.info(str(path))

        if info.channels > 2:
            raise ValueError("Invalid audio format")
        elif info.channels == 1:
            self.stereo_width = 0
        else:
            self.stereo_width = get_stereo_width(str(path))

        self.name: str = path.stem

        self.lufs: float = get_lufs(audio, sr)

        mel_spec = librosa.feature.melspectrogram(y=audio, sr=sr)
        S = spectral_centroid(mel_spec)
        self.spectral_centroid = np.median(filter_nan(S))
        if self.spectral_centroid < 40:
            self.spectral_centroid = np.max(filter_nan(S))

        R = rolloff(audio, sr)
        self.rolloff = np.median(filter_nan(R))
        if self.rolloff < 40:
            self.rolloff = np.max(filter_nan(R))

        self.mfcc = mfcc(audio, sr)
        # self.fundamental: np.ndarray = pyin_fund(audio, sr)
        # self.rolloff: np.ndarray = rolloff(audio, sr)

        # print(f"{self.name} - {self.spectogram}")
