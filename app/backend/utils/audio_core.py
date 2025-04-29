from pathlib import Path

import soundfile as sf

from app.backend.models import AudioFormat

from .hash import get_file_hash


class AudioMeta:
    def __init__(self, path: Path):
        self.name: str = path.stem
        self.format: AudioFormat | None = get_file_format(path)
        self.hash = get_file_hash(path)

        info = sf.info(path)
        self.duration: float = info.duration
        self.sample_rate = info.samplerate
        self.channels = info.channels


def get_file_format(path: Path) -> AudioFormat | None:
    supported_formats = {fmt.value for fmt in AudioFormat}
    suffix = path.suffix.lower()
    if suffix not in supported_formats:
        return None
    return AudioFormat(suffix)


__all__ = ["AudioMeta"]
