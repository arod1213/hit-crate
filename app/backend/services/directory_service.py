import threading
from pathlib import Path
from typing import Optional

from sqlmodel import Session

from app.backend.repos.directory_repo import DirectoryRepo
from app.backend.utils.file_watch import scan_dir

from ..models import Directory


class DirectoryService:
    def __init__(self, db: Session):
        self.session = db
        self.repo = DirectoryRepo(db)

    def query(self, path: Path) -> Optional[Directory]:
        return self.repo.query(path)

    def query_directories(self):
        return self.repo.query_directories()

    def create(self, path: Path):
        new_dir = self.repo.create(path)
        if new_dir is not None:
            new_thread = threading.Thread(
                target=scan_dir, args=(path,), daemon=True
            )
            new_thread.start()

    def delete(self, path: str):
        return self.repo.delete(path)
