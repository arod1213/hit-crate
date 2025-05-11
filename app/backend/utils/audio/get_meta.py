from pathlib import Path

import soundfile as sf

from app.backend.models import AudioFormat

from ..hash import get_file_hash
from .core import get_file_format


class AudioMeta:
    def __init__(self, path: Path):
        self.name: str = path.stem
        self.format: AudioFormat | None = get_file_format(path)
        self.hash = get_file_hash(path)

        info = sf.info(path)
        self.duration: float = info.duration
        self.sample_rate = info.samplerate
        self.channels = info.channels

