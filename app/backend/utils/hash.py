import hashlib
from pathlib import Path


def get_file_hash(path: Path, chunk_size: int = 8192) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as f:
        while chunk := f.read(chunk_size):
            hasher.update(chunk)
    return hasher.hexdigest()
