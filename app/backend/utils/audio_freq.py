import librosa
import numpy as np


def mel_spectogram(audio: np.ndarray, sr: int | float):
    S = librosa.feature.melspectrogram(y=audio, sr=sr, power=2)
    S_db = librosa.power_to_db(S, ref=np.max)
    return S_db[0]


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
