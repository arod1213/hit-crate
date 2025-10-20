from app.backend.schemas import AudioFormat
from pathlib import Path


def get_valid_files(path: Path):
    supported_formats = {fmt.value for fmt in AudioFormat}
    return filter(lambda f: f.suffix.lower() in supported_formats, path.rglob("*"))
