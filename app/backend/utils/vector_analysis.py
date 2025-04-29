import numpy as np
import librosa


def dtw_to_probability(dtw_distance, mean_distance=0, alpha=1):
    return 1 / (1 + np.exp(alpha * (dtw_distance - mean_distance)))


def dtw_similarity(a: np.ndarray, b: np.ndarray) -> float:
    min_len = min(a.shape[1], b.shape[1])
    a = a[:, :min_len]
    b = b[:, :min_len]

    if min_len < 7:
        return 0
    elif min_len < 12 and a.shape[1] != b.shape[1]:
        return 0

    D, _ = librosa.sequence.dtw(a.T, b.T)
    distance = D[-1, -1]
    # return distance
    # if distance < 2000:
    #     print("INITIAL DISTANCE", distance)
    value = dtw_to_probability(distance, mean_distance=700)
    if value > 0.95:
        print(min_len, a.shape[1], b.shape[1])
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
