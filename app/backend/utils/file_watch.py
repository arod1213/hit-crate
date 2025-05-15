import os
from datetime import datetime
from pathlib import Path
from typing import Optional

from sqlmodel import Session

from app.backend.db import engine
from app.backend.models import Sample
from app.backend.schemas import AudioFormat
from app.backend.services.sample_service import SampleService
from app.backend.utils.audio.checks import is_one_shot


def scan_dir(path: Path):
    with Session(engine, expire_on_commit=False) as session:

        child_samples = SampleService(session).query_by_parent(path)
        existing_samples = {sample.path: sample for sample in child_samples}

        dir_files = get_valid_files(path)

        for file in dir_files:
            if not file.is_file():
                continue
            matching_sample = existing_samples.get(str(file))
            file_added = check_file(
                file, matching_sample, parent_path=path, session=session
            )
            if not file_added:
                matching_sample = existing_samples.get(str(file))
                SampleService(session).delete(file)


def check_file(
    path: Path,
    matching_sample: Optional[Sample],
    parent_path: Path,
    session: Session,
) -> bool:
    if not is_one_shot(path):
        return False
    # if sf.info(str(path)).duration > 5:  # only load short samples
    #     return False

    m_time_float = os.path.getmtime(path)
    modified_at = datetime.fromtimestamp(m_time_float)

    if matching_sample:
        if modified_at != matching_sample.modified_at:
            print(f"{matching_sample.path} is being updated")
            SampleService(session).update(path, is_favorite=None)
            session.commit()
            return True
    else:
        print(f"{path} does not exist - creating file")
        SampleService(session).create(path, parent_path)
        session.commit()
        return True
    return True


def get_valid_files(path: Path):
    supported_formats = {fmt.value for fmt in AudioFormat}
    return (
        f for f in path.rglob("*") if f.suffix.lower() in supported_formats
    )
