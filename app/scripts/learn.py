from pathlib import Path
from typing import Tuple

import librosa
import numpy as np
from app.backend.schemas import AudioFormat
from app.backend.utils.audio_freq import spectral_centroid
from app.backend.utils.audio_width import get_stereo_width

WATCH_DIR = Path.home() / "Desktop" / "Scan Test"
FILE = Path.home() / "Desktop" / "Scan Test" / "WIDEST.wav"
# FILE2 = Path.home() / "Desktop" / "Scan Test" / "AS_KICK_.wav"


def get_valid_files(path: Path):
    supported_formats = {fmt.value for fmt in AudioFormat}
    return (
        f for f in path.rglob("*") if f.suffix.lower() in supported_formats
    )


def load_audio(path: str) -> Tuple[np.ndarray, int | float]:
    audio, sr = librosa.load(path, mono=True, res_type="soxr_lq")
    return (audio, sr)


def filter_nan(arr):
    return arr[~np.isnan(arr)]


class AudioAnalysis:
    def __init__(self, path: Path):
        audio, sr = load_audio(str(path))

        self.name: str = path.stem
        self.mfcc: np.ndarray = mfcc(audio, sr)[1:, :]
        self.fundamental: np.ndarray = pyin_fund(audio, sr)

        x = filter_nan(self.fundamental)
        # print(f"FUND of {self.name}",  np.mean(x), np.median(x))
        self.rolloff: np.ndarray = rolloff(audio, sr)
        self.spectral_centroid = spectral_centroid(audio, sr)

        self.spectral_centroid = np.median(filter_nan(self.spectral_centroid))
        # print(f"{self.name} - {self.spectogram}")


def mel_spectogram(audio: np.ndarray, sr: int | float):
    S = librosa.feature.melspectrogram(y=audio, sr=sr, power=2)
    S_db = librosa.power_to_db(S, ref=np.max)
    return S_db[0]


def rolloff(audio: np.ndarray, sr: int | float):
    data = librosa.feature.spectral_rolloff(y=audio, sr=sr)
    return data[0]


def pyin_fund(audio: np.ndarray, sr: int | float):
    # equilibrium = 10
    # mult = 1 if curve_avg > equilibrium else 2.5
    fmin = 40
    data = librosa.pyin(
        y=audio, fmin=fmin, fmax=2000, sr=sr, boltzmann_parameter=5
    )
    return data[0]


def mfcc(audio: np.ndarray, sr: int | float):
    data = librosa.feature.mfcc(y=audio, sr=sr, n_mfcc=20)
    return data


def cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    min_length = min(len(a), len(b))
    if min_length == 0:
        return 0.0

    a = np.nan_to_num(a[:min_length])
    b = np.nan_to_num(b[:min_length])

    dot = np.dot(a, b)
    lin_a = np.linalg.norm(a)
    lin_b = np.linalg.norm(b)

    if not lin_a or not lin_b:
        return 0.0

    return dot / (lin_a * lin_b)


def similarity_score(x: AudioAnalysis, y: AudioAnalysis):
    fundamental = cosine_similarity(x.fundamental, y.fundamental)
    rolloff = cosine_similarity(x.rolloff, y.rolloff)

    weights = [
        (fundamental, 1),
        (rolloff, 2.5),
    ]

    if fundamental == 0:
        weights = [
            (fundamental, 0.2),
            (rolloff, 2.5),
        ]

    score_sum = 0
    weight_sum = sum(weight for _, weight in weights)

    for score, weight in weights:
        weight /= weight_sum
        score_sum += score * weight

    return score_sum


# def traverse():
#     for path in get_valid_files(WATCH_DIR):
#         if not path.is_file():
#             continue
#         y = AudioAnalysis(path)


def main():
    # x = get_stereo_width(str(FILE))
    # print("X WIDTH IS", x)
    # bench_time = repeat(
    #     stmt="fn()",
    #     globals={"fn": traverse},
    #     repeat=2,
    #     number=10
    # )
    # print(f"bench time {bench_time}")
    for path in get_valid_files(WATCH_DIR):
        if not path.is_file():
            continue
        y = AudioAnalysis(path)
        print(f"{y.name}")
        print(f"Centroid: {y.spectral_centroid}")
        # print(f"SIM {x.name} - {y.name}:", f"{similarity_score(x, y):.3f}")


if __name__ == "__main__":
    main()
