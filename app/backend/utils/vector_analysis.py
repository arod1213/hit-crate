import math

import librosa
import numpy as np


def dtw_to_probability(dtw_distance):
    """
    Convert DTW distance to a probability-like similarity score.
    """
    if dtw_distance > 3000:  # outside of acceptable range
        return 0

    k = 0.00462
    decay_rate = k * (dtw_distance - 1500)

    denom = 1 + math.e**decay_rate
    return 1 / denom


def dtw_similarity(a: np.ndarray, b: np.ndarray) -> float:
    len_a = a.shape[1]
    len_b = b.shape[1]
    min_len = min(len_a, len_b)

    if min_len < 7:
        return 0
    elif min_len < 12 and a.shape[1] != b.shape[1]:
        return 0

    # a = a[:, :min_len]
    # b = b[:, :min_len]
    max_len = max(len_a, len_b)
    a = np.pad(a, (0, max_len - len_a), mode="constant", constant_values=0)
    b = np.pad(b, (0, max_len - len_b), mode="constant", constant_values=0)

    D, _ = librosa.sequence.dtw(a.T, b.T)
    distance = D[-1, -1]
    value = dtw_to_probability(distance)
    return value


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
