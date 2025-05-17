from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from sqlmodel import Session

from app.backend.db import engine
from app.backend.services import DirectoryService


def perform_scan(path: Path):
    with Session(engine) as session:
        service = DirectoryService(session)
        service.rescan(path)


def run_initial_scan():
    with Session(engine, expire_on_commit=False) as session:
        dirs = DirectoryService(session).query_directories()
        paths = (Path(d.path) for d in dirs)

    with ThreadPoolExecutor(
        max_workers=5, thread_name_prefix="scan_worker"
    ) as executor:
        for path in paths:
            executor.submit(perform_scan, path)
