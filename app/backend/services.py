from pathlib import Path
from typing import Sequence

from sqlmodel import Session

from app.backend.repos.directory_repo import DirectoryRepo
from app.backend.utils.to_bytes import array_to_bytes

from .models import Sample
from .repos.sample_repo import SampleRepo
from .schemas import (
    SampleCreateInput,
    SampleQueryInput,
    SampleSimilarInput,
    SampleUpdateInput,
)
from .utils.audio_core import AudioMeta
from .utils.audio_detail import AudioDetail


class SampleService:
    def __init__(self, db: Session):
        self.repo = SampleRepo(db)

    def query(self, path: Path):
        return self.repo.query(path)

    def query_samples(self, input: SampleQueryInput) -> Sequence[Sample]:
        """Get all users."""
        return self.repo.query_samples(input)

    def query_similar(self, path: Path, input: SampleSimilarInput):
        return self.repo.query_similar(path, input)

    def create(self, path: Path) -> Sample:
        if not path.is_file():
            raise IsADirectoryError(f"path: {path} is a directory")

        metadata = AudioMeta(path)
        if metadata.format is None:  # if unsupported
            raise ValueError(f"{metadata.format} is unsupported")
        detail = AudioDetail(path)

        return self.repo.create(
            input=SampleCreateInput(
                path=path,
                format=metadata.format,
                duration=metadata.duration,
                sample_rate=metadata.sample_rate,
                hash=metadata.hash,
                rms=detail.rms,
                stereo_width=detail.stereo_width,
                mfcc=array_to_bytes(detail.mfcc),
                spectral_centroid=detail.spectral_centroid,
            )
        )

    def update(self, path: Path):
        if not path.is_file():
            return

        metadata = AudioMeta(path)
        if metadata.format is None:  # if unsupported
            # delete file here ?
            return
        detail = AudioDetail(path)

        input = SampleUpdateInput(
            duration=metadata.duration,
            format=metadata.format,
            hash=metadata.hash,
            sample_rate=metadata.sample_rate,
            rms=detail.rms,
        )
        return self.repo.update(path, input)

    def update_path(self, src_path: Path, dest_path: Path):
        return self.repo.update_path(src_path, dest_path)

    def delete(self, path: Path):
        if not path.is_file():
            return
        found_file = self.repo.query(path)
        if not found_file:
            return
        return self.repo.delete(path)


class DirectoryService:
    def __init__(self, db: Session):
        self.repo = DirectoryRepo(db)

    def query_directories(self):
        return self.repo.query_directories()

    def create(self, path: Path):
        return self.repo.create(path)

    def delete(self, path: str):
        return self.repo.delete(path)
