import os
from datetime import datetime
from pathlib import Path

import soundfile as sf
from sqlalchemy import func
from sqlmodel import Session, select
from watchdog.events import FileSystemEventHandler

from app.backend.services import DirectoryService, SampleService

from .db import engine
from .models import Sample
from .schemas import AudioFormat

WATCH_DIR = Path.home() / "Desktop" / "Scan Test"


def get_valid_files():
    supported_formats = {fmt.value for fmt in AudioFormat}
    valid_files = []
    with Session(engine) as db_session:
        directories = DirectoryService(db_session).query_directories()
        for dir in directories:
            dir_path = Path(dir.path)
            valid_files.extend(
                f for f in dir_path.rglob("*")
                if f.suffix.lower() in supported_formats
            )
    return valid_files


def run_initial_scan():
    valid_files = list(get_valid_files())
    with Session(engine, expire_on_commit=False) as session:

        existing_samples = {
            sample.path: sample
            for sample in session.exec(
                select(Sample).where(
                    func.lower(Sample.path).in_(
                        [str(f).lower() for f in valid_files]
                    )
                )
            ).all()
        }
        for path in valid_files:
            if not path.is_file():
                continue

            try:
                if (
                    sf.info(str(path)).duration > 4.5
                ):  # only load short samples
                    continue

                m_time_float = os.path.getmtime(path)
                modified_at = datetime.fromtimestamp(m_time_float)
                existing_sample = existing_samples.get(str(path))

                if existing_sample:
                    if modified_at != existing_sample.modified_at:
                        print(f"{existing_sample.path} is being updated")
                        SampleService(session).update(path)
                        session.commit()
                else:
                    print(f"{path} does not exist - creating file")
                    SampleService(session).create(path)
                    session.commit()
            except sf.LibsndfileError:
                print(f"{path} could not be opened with soundfile")


class Handler(FileSystemEventHandler):
    def on_created(self, event):
        if event.is_directory:
            return
        db_session = Session(engine)
        path = Path(str(event.src_path))
        SampleService(db_session).create(path)

    def on_deleted(self, event):
        if event.is_directory:
            return
        db_session = Session(engine)
        path = Path(str(event.src_path))
        SampleService(db_session).delete(path)

    def on_modified(self, event):
        if event.is_directory:
            return
        db_session = Session(engine)
        path = Path(str(event.src_path))
        SampleService(db_session).update(path)

    # def on_any_event(self, event) -> None:
    #     print(event.src_path)

    def on_moved(self, event):
        if event.is_directory:
            return
        db_session = Session(engine)
        path = Path(str(event.src_path))
        dest_path = Path(str(event.dest_path))
        SampleService(db_session).update_path(path, dest_path)


def watchdog(func):
    def wrapper(*args, **kwargs):
        # observer = Observer()
        # handler = Handler()
        # observer.schedule(handler, str(WATCH_DIR), recursive=True)
        # observer.start()

        func(*args, **kwargs)

    return wrapper
