import threading
import time
from pathlib import Path
from typing import Optional

import pygame

from app.backend.models import Sample
from app.frontend.store import Store

from .utils.gain import amp_to_target_lufs


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

    def load_audio(self, sample: Sample):
        """Load the audio file."""
        if self.is_playing:
            self.stop()
        file_path = Path(sample.path)
        if file_path.exists():
            self.sample = sample
            self.file_path = file_path
            self.sound = pygame.mixer.Sound(str(file_path))
        # else:
        #     print(f"File not found: {file_path}")

    def play(self):
        """Play the audio in a separate thread."""
        if self.file_path is None:
            # print("No audio file loaded.")
            return
        if self.is_playing:
            self.stop()

        if self.file_path.exists():
            # print("Playing audio...")
            self.is_playing = True  # Set the state to playing

            # Run audio in a separate thread
            threading.Thread(target=self._play_audio).start()

        # else:
        #     print(f"Audio file not found: {self.file_path}")
        # else:
        #     print("Audio is already playing.")

    def _play_audio(self):
        """Internal method to play the audio in the background."""
        if self.sample is None:
            return
        self.load_audio(self.sample)
        if self.sound is None:
            return

        if self.even_gain and self.sample:
            lufs = self.sample.lufs
            if lufs:
                target_lufs = self._store._state.lufs_target
                target_gain = amp_to_target_lufs(curr=lufs, target=target_lufs)
                self.sound.set_volume(target_gain)

        self.channel = self.sound.play(loops=0)

        # Wait until the music is done playing
        while self.channel.get_busy():
            time.sleep(0.1)

        self.is_playing = False  # Set the state to not playing once done
        # print("Audio finished playing.")

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
