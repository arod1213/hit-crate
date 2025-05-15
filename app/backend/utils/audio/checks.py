from typing import Tuple
import numpy as np
import soundfile as sf
import librosa
from pathlib import Path


def is_one_shot(path: Path) -> bool:
    """
    Return: true if one shot else false
    """
    try:
        metadata = sf.info(path)
        # if short file
        if metadata.duration < 5:
            return True
        elif metadata.duration > 20:
            return False  # prevent scanning long files

        audio, sr = librosa.load(path, mono=True)
        peak = np.max(audio)
        if peak != 0:
            audio = audio * (1 / peak)

        rms_values, num_frames = rms_envelope(audio, sr)
        rms_feature = rms_energy(rms_values, num_frames)
        if rms_feature > 50:
            return True
        # print(f"{path} is a loop")
        return False
    except sf.LibsndfileError:
        print(f"{path} could not be opened with soundfile")
        return False


def rms_envelope(audio: np.ndarray, sr: int | float) -> Tuple[np.ndarray, int]:
    window_size = int(sr * 0.03)  # 30ms window
    hop_size = int(window_size / 2)

    num_frames = (len(audio) - window_size) // hop_size + 1
    rms_values = np.zeros(num_frames)  # init array

    for i in range(num_frames):
        start = i * hop_size
        end = start + window_size
        frame = audio[start:end]
        rms_values[i] = np.sqrt(np.mean(frame ** 2))

    return rms_values, num_frames


def rms_energy(rms_values: np.ndarray, num_frames: int):
    peak_rms = np.max(rms_values)
    end_energy = np.mean(rms_values[-int(num_frames / 3):])
    if end_energy == 0:
        if peak_rms == 0:
            return False
        return peak_rms / 1e-10
    return peak_rms / end_energy
