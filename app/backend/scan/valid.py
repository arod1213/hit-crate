from pathlib import Path

from app.backend.schemas import AudioFormat


def get_valid_files(path: Path):
    supported_formats = {fmt.value for fmt in AudioFormat}
    return (f for f in path.rglob("*") if f.suffix.lower() in supported_formats)
