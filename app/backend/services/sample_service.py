import os
from datetime import datetime
from pathlib import Path
from typing import Optional, Sequence

from sqlmodel import Session

from app.backend.repos.directory_repo import DirectoryRepo
from app.backend.utils.audio.checks import is_one_shot
from app.backend.utils.to_bytes import array_to_bytes

from ..models import Sample
from ..repos.sample_repo import SampleRepo
from ..schemas import (
    SampleCreateInput,
    SampleQueryInput,
    SampleSimilarInput,
    SampleUpdateInput,
)
from ..utils.audio import AudioDetail, AudioMeta


class SampleService:
    def __init__(self, db: Session):
        self.repo = SampleRepo(db)
        self.directory_repo = DirectoryRepo(db)

    def query(self, path: Path):
        return self.repo.query(path)

    def query_samples(self, input: SampleQueryInput) -> Sequence[Sample]:
        """Get all users."""
        return self.repo.query_samples(input)

    def query_similar(self, path: Path, input: SampleSimilarInput):
        return self.repo.query_similar(path, input)

    def query_by_parent(self, path: Path):
        return self.repo.query_by_parent(path)

    def create(self, path: Path, parent_path: Path) -> Sample:
        if not path.is_file():
            raise IsADirectoryError(f"path: {path} is a directory")
        parent_dir = self.directory_repo.query(parent_path)
        if not parent_dir:
            raise ValueError(f"{parent_path} could not be found")

        metadata = AudioMeta(path)
        if metadata.format is None:  # if unsupported
            raise ValueError(f"{metadata.format} is unsupported")
        detail = AudioDetail(path)

        return self.repo.create(
            input=SampleCreateInput(
                path=path,
                parent_path=parent_path,
                format=metadata.format,
                duration=metadata.duration,
                sample_rate=metadata.sample_rate,
                hash=metadata.hash,
                lufs=detail.lufs,
                stereo_width=detail.stereo_width,
                mfcc=array_to_bytes(detail.mfcc),
                spectral_centroid=detail.spectral_centroid,
                rolloff=detail.rolloff,
            )
        )

    def update(
        self, path: Path, is_favorite: Optional[bool]
    ) -> Optional[Sample]:
        if not path.is_file():
            return

        metadata = AudioMeta(path)
        if metadata.format is None:  # if unsupported
            self.delete(path)
            return

        detail = AudioDetail(path)

        input = SampleUpdateInput(
            is_favorite=is_favorite,
            duration=metadata.duration,
            format=metadata.format,
            hash=metadata.hash,
            sample_rate=metadata.sample_rate,
            lufs=detail.lufs,
        )
        return self.repo.update(path, input)

    def update_path(self, src_path: Path, dest_path: Path):
        return self.repo.update_path(src_path, dest_path)

    def delete(self, path: Path):
        if not path.is_file() and path.exists():
            return
        found_file = self.repo.query(path)
        if not found_file:
            return
        return self.repo.delete(path)

    def rescan(self, path: Path, parent_path: Path, matching_sample: Optional[Sample]):
        if not is_one_shot(path):
            if matching_sample:
                self.delete(path)
            return
        if matching_sample:
            m_time_float = os.path.getmtime(path)
            modified_at = datetime.fromtimestamp(m_time_float)
            if modified_at != matching_sample.modified_at:
                self.update(path, is_favorite=None)
        else:
            self.create(path, parent_path)
