import io
import threading
import time
from pathlib import Path
from typing import Optional

import librosa
import numpy as np
import pygame
from scipy.io import wavfile

from app.backend.models import Sample
from app.frontend.store import Store

from .utils.gain import amp_to_target_lufs


def amplify_audio(path: str, target_gain: float):
    y, sr = librosa.load(path, sr=None, mono=False)

    max_peak = np.max(np.abs(y))
    if max_peak * target_gain > 1 and max_peak != 0:
        target_gain = 1 / max_peak
        y = y * target_gain
    else:
        y = y * target_gain

    y_int = (y * 32767).astype(np.int16)
    buffer = io.BytesIO()
    if y.ndim > 1 and y.shape[0] == 2:
        y_int = y_int.T

    y = np.clip(y, -1, 1)
    # Write to buffer
    wavfile.write(buffer, sr, y_int)
    buffer.seek(0)
    return buffer


class AudioEngine:
    pygame.mixer.init()

    def __init__(self):
        self._store = Store()

        self.file_path: Path | None = None
        self.is_playing = False  # Add a boolean to track the playing status
        self.even_gain = True
        self.sample: Optional[Sample] = None
        self.sound: Optional[pygame.mixer.Sound] = None
        self.channel: Optional[pygame.mixer.Channel] = None

    def load_audio(self, sample: Sample) -> bool:
        """Load the audio file.
        Returns False if audio should be stopped and true if ready to be played
        """
        if str(self.file_path) == sample.path:
            if self.is_playing:
                self.stop()
                return False
            return True

        if self.is_playing:
            self.stop()
        file_path = Path(sample.path)
        if file_path.exists():
            self.sample = sample
            self.file_path = file_path
            self.sound = pygame.mixer.Sound(str(file_path))
        return True

    def play(self):
        """Play the audio in a separate thread."""
        if self.file_path is None:
            # print("No audio file loaded.")
            return
        if self.file_path.exists():
            self.is_playing = True
            playback_thread = threading.Thread(
                target=self._play_audio, daemon=True
            )
            playback_thread.start()

    def _play_audio(self):
        """Internal method to play the audio in the background."""
        if self.sample is None or self.sound is None:
            return

        if self.even_gain and self.sample:
            lufs = self.sample.lufs
            if lufs:
                target_lufs = self._store._state.lufs_target
                target_gain = amp_to_target_lufs(curr_lufs=lufs, target=target_lufs)
                if target_gain > 1:
                    buffer = amplify_audio(self.sample.path, target_gain)
                    self.sound = pygame.mixer.Sound(buffer)
                    target_gain = 1  # reset after amplification
                self.sound.set_volume(target_gain)

        self.channel = self.sound.play(loops=0)

        # Wait until the music is done playing
        while self.channel.get_busy():
            time.sleep(0.1)

        self.is_playing = False  # Set the state to not playing once done

    def stop(self):
        """Stop the audio."""
        if self.channel is not None:
            self.channel.stop()
            self.is_playing = False
        # else:
        #     print("No audio is currently loaded.")

    def is_audio_playing(self):
        """Check if the audio is currently playing."""
        return self.is_playing
