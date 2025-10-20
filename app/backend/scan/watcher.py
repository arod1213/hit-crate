from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from sqlmodel import Session

from app.backend.db import engine
from app.backend.services.hold import get_directories, rescan_directory


def perform_scan(path: Path):
    with Session(engine) as db:
        rescan_directory(db, path)


def run_initial_scan():
    with Session(engine, expire_on_commit=False) as db:
        dirs = get_directories(db)
        paths = (Path(d.path) for d in dirs)

    with ThreadPoolExecutor(
        max_workers=5, thread_name_prefix="scan_worker"
    ) as executor:
        for path in paths:
            executor.submit(perform_scan, path)
