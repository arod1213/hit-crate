import os
from datetime import datetime
from pathlib import Path
from typing import Optional

import soundfile as sf
from sqlmodel import Session, select

from app.backend.db import engine
from app.backend.models import Sample
from app.backend.schemas import AudioFormat
from app.backend.services.sample_service import SampleService


def scan_dir(path: Path):
    with Session(engine, expire_on_commit=False) as session:
        existing_samples = {
            sample.path: sample
            for sample in session.exec(
                select(Sample).where(Sample.parent_path == str(path))
            ).all()
        }
        dir_files = get_valid_files(path)

        for file in dir_files:
            if not file.is_file():
                continue
            matching_sample = existing_samples.get(str(file))
            check_file(
                file, matching_sample, parent_path=path, session=session
            )
        pass

def check_file(
    path: Path,
    matching_sample: Optional[Sample],
    parent_path: Path,
    session: Session,
):
    try:
        if sf.info(str(path)).duration > 5:  # only load short samples
            return

        m_time_float = os.path.getmtime(path)
        modified_at = datetime.fromtimestamp(m_time_float)

        if matching_sample:
            if modified_at != matching_sample.modified_at:
                print(f"{matching_sample.path} is being updated")
                SampleService(session).update(path, is_favorite=None)
                session.commit()
        else:
            print(f"{path} does not exist - creating file")
            SampleService(session).create(path, parent_path)
            session.commit()
    except sf.LibsndfileError:
        print(f"{path} could not be opened with soundfile")


def get_valid_files(path: Path):
    supported_formats = {fmt.value for fmt in AudioFormat}
    return (
        f for f in path.rglob("*") if f.suffix.lower() in supported_formats
    )
