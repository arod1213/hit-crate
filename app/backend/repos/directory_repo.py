from pathlib import Path
from typing import Optional, Sequence

from sqlmodel import Session, select

from app.backend.repos.sample_repo import SampleRepo

from ..models import Directory


class DirectoryRepo:
    def __init__(self, session: Session):
        self.session = session

    def query(self, path: Path):
        return self.session.exec(
            select(Directory).where(Directory.path == str(path))
        ).first()

    def query_directories(self) -> Sequence[Directory]:
        return self.session.exec(select(Directory)).all()

    def create(self, path: Path) -> Directory:
        exists = self.query(path)
        if exists:
            return exists

        dir = Directory(path=str(path))
        self.session.add(dir)
        self.session.commit()
        self.session.refresh(dir)
        return dir

    def delete(self, path: str) -> Optional[Directory]:
        dir = self.session.exec(
            select(Directory).where(Directory.path == str(path))
        ).first()

        if not dir:
            return None

        samples = SampleRepo(self.session).query_by_parent(Path(path))
        for s in samples:
            self.session.delete(s)

        self.session.delete(dir)
        self.session.commit()
        return dir
