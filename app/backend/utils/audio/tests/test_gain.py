import numpy as np
from app.backend.utils.audio.gain import get_lufs


def test_get_lufs_basic():
    sr = 44100  # 44.1 kHz
    duration = 1  # 1 second
    t = np.linspace(0, duration, int(sr * duration), endpoint=False)

    # Generate a 440 Hz sine wave (A4 tone)
    sine_wave = 0.5 * np.sin(2 * np.pi * 440 * t)

    loudness = get_lufs(sine_wave, sr)

    assert isinstance(loudness, float)
    assert -70 < loudness < 0  # LUFS range for audio (sanity check)


def test_get_lufs_padding_short_audio():
    sr = 44100
    short_audio = np.random.randn(int(0.1 * sr)) * 0.01  # 0.1 sec noise

    lufs = get_lufs(short_audio, sr, min_duration=0.5)
    assert isinstance(lufs, float)


def test_get_lufs_zero_signal():
    sr = 44100
    silence = np.zeros(int(0.5 * sr))

    lufs = get_lufs(silence, sr)
    assert lufs == float('-inf') or lufs < -100
