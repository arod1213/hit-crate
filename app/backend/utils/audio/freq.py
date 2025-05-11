import librosa
import numpy as np


def rolloff(audio: np.ndarray, sr: int | float):
    data = librosa.feature.spectral_rolloff(y=audio, sr=sr)
    return data[0]


def pyin_fund(audio: np.ndarray, sr: int | float):
    data = librosa.pyin(y=audio, fmin=40, fmax=2000, sr=sr)
    return data[0]


def mfcc(audio: np.ndarray, sr: int | float):
    data = librosa.feature.mfcc(y=audio, sr=sr, n_mfcc=20)
    return data


def spectral_centroid(mel_spec: np.ndarray):
    data = librosa.feature.spectral_centroid(S=mel_spec)
    return data[0]
