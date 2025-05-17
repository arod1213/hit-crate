import threading
from pathlib import Path
from typing import Optional

from sqlmodel import Session

from app.backend.repos.directory_repo import DirectoryRepo
from app.backend.scan.valid import get_valid_files
from app.backend.services.sample_service import SampleService

from ..models import Directory


class DirectoryService:
    def __init__(self, db: Session):
        self.session = db
        self.repo = DirectoryRepo(db)
        self.sample_service = SampleService(db)

    def query(self, path: Path) -> Optional[Directory]:
        return self.repo.query(path)

    def query_directories(self):
        return self.repo.query_directories()

    def create(self, path: Path):
        new_dir = self.repo.create(path)
        if new_dir is not None:
            new_thread = threading.Thread(
                target=self.rescan, args=(path,), daemon=True
            )
            new_thread.start()

    def delete(self, path: str):
        return self.repo.delete(path)

    def rescan(self, path: Path):
        child_samples = self.sample_service.query_by_parent(path)
        existing_samples = {sample.path: sample for sample in child_samples}

        valid_files = get_valid_files(path)

        for file in valid_files:
            if not file.is_file():
                continue
            matching_sample = existing_samples.get(str(file))
            self.sample_service.rescan(path, file, matching_sample)
