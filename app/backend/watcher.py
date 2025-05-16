from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from sqlmodel import Session
from watchdog.events import FileSystemEventHandler

from app.backend.services import DirectoryService, SampleService
from app.backend.utils.file_watch import scan_dir

from .db import engine


def run_initial_scan():
    with Session(engine, expire_on_commit=False) as session:
        dirs = DirectoryService(session).query_directories()
        paths = (Path(d.path) for d in dirs)

    with ThreadPoolExecutor(
        max_workers=64, thread_name_prefix="scan_worker"
    ) as executor:
        for path in paths:
            executor.submit(scan_dir, path)


class Handler(FileSystemEventHandler):
    def on_created(self, event):
        if event.is_directory:
            return
        # db_session = Session(engine)
        # path = Path(str(event.src_path))
        # SampleService(db_session).create(path)

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
        SampleService(db_session).update(path, is_favorite=None)

    # def on_any_event(self, event) -> None:
    #     print(event.src_path)

    def on_moved(self, event):
        if event.is_directory:
            return
        db_session = Session(engine)
        path = Path(str(event.src_path))
        dest_path = Path(str(event.dest_path))
        SampleService(db_session).update_path(path, dest_path)


# def watchdog(func):
#     def wrapper(*args, **kwargs):
#         # observer = Observer()
#         # handler = Handler()
#         # observer.schedule(handler, str(WATCH_DIR), recursive=True)
#         # observer.start()
#
#         func(*args, **kwargs)
#
#     return wrapper
