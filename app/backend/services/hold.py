import os
import threading
from datetime import datetime
from pathlib import Path
from typing import Optional, Sequence

from sqlmodel import Session, func, nullslast, or_, select

from app.backend.scan.valid import get_valid_files
from app.backend.utils.audio.checks import is_one_shot
from app.backend.utils.to_bytes import array_to_bytes
from app.backend.utils.tokenizer import tokenize

from ..models import Directory, Sample
from ..schemas import (
    SampleQueryInput,
    SampleSimilarInput,
    SampleUpdateInput,
    SampleUpdateMetaInput,
)
from ..utils.audio import AudioDetail, AudioMeta
from ..utils.vector_compare import sort_by_freq


def create_sample(db: Session, path: Path, parent_path: Path) -> Sample:
    if not path.is_file():
        raise IsADirectoryError(f"path: {path} is a directory")
    parent_dir = get_directory(db, parent_path)
    if not parent_dir:
        raise ValueError(f"{parent_path} could not be found")

    match = get_sample(db, path)
    if match is not None:
        return match

    metadata = AudioMeta(path)
    if metadata.format is None:  # if unsupported
        raise ValueError(f"{metadata.format} is unsupported")
    detail = AudioDetail(path)

    existing = db.exec(select(Sample).where(Sample.path == str(path))).first()

    if existing:
        return existing

    m_time_float = os.path.getmtime(path)
    sample = Sample(
        name=path.stem,
        modified_at=datetime.fromtimestamp(m_time_float),
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

    db.add(sample)
    db.commit()
    db.refresh(sample)
    return sample


def delete_sample(db: Session, path: Path):
    sample = db.exec(select(Sample).where(Sample.path == str(path))).first()

    if not sample:
        return None
    db.delete(sample)
    db.commit()
    return sample


def get_sample(db: Session, path: Path):
    return db.exec(select(Sample).where(Sample.path == str(path))).first()


def update_sample_meta(db: Session, path: Path):
    metadata = AudioMeta(path)
    if metadata.format is None:  # if unsupported
        delete_sample(db, path)
        return

    detail = AudioDetail(path)

    input = SampleUpdateMetaInput(
        duration=metadata.duration,
        format=metadata.format,
        hash=metadata.hash,
        sample_rate=metadata.sample_rate,
        lufs=detail.lufs,
    )
    return update_sample(db, path, input)


def update_sample(
    db: Session, path: Path, input: SampleUpdateInput | SampleUpdateMetaInput
) -> Optional[Sample]:
    sample = db.exec(select(Sample).where(Sample.path == str(path))).first()
    if sample is None:
        return None

    m_time_float = os.path.getmtime(path)
    sample.modified_at = datetime.fromtimestamp(m_time_float)

    for attr in dir(input):
        if not attr.startswith("_") and hasattr(sample, attr):
            value = getattr(input, attr)
            if value is None:
                continue
            setattr(sample, attr, value)

    db.add(sample)
    db.commit()
    db.refresh(sample)

    return sample


def get_similar_samples(
    db: Session,
    path: Path,
    input: SampleSimilarInput,
) -> Sequence[Sample]:
    found = db.exec(select(Sample).where(Sample.path == str(path))).first()
    if not found:
        return []

    conditions = []
    if found.stereo_width is not None and input.byWidth:
        conditions.append(Sample.stereo_width is not None)
        conditions.append(func.abs(Sample.stereo_width - found.stereo_width) < 8)

    matches = db.exec(
        select(Sample)
        .where(*conditions)
        .order_by(nullslast(func.abs(Sample.stereo_width - found.stereo_width).asc()))
    ).all()

    if input.byFreq:
        matches = sort_by_freq(found, matches)

    return matches


def rescan_sample(
    db: Session, path: Path, parent_path: Path, matching_sample: Optional[Sample]
):
    if not is_one_shot(path):
        if matching_sample:
            delete_sample(db, path)
        return
    if matching_sample:
        m_time_float = os.path.getmtime(path)
        modified_at = datetime.fromtimestamp(m_time_float)
        if modified_at != matching_sample.modified_at:
            update_sample_meta(db, path)
    else:
        # print("create")
        create_sample(db, path, parent_path)


def get_directories(db: Session):
    return db.exec(select(Directory)).all()


def get_samples_by_directory(db: Session, path: Path):
    return db.exec(
        select(Sample).where(
            or_(
                Sample.parent_path == str(path),
                Sample.path.contains(str(path)),
            )
        )
    ).all()


def get_samples(self, input: SampleQueryInput) -> Sequence[Sample]:
    conditions = []
    order_conditions = []

    # audio properties
    if input.width is not None and input.spectral_centroid is None:
        order_conditions.append(
            func.abs(Sample.stereo_width - input.width).asc()  # type: ignore[arg-type]
        )

    if input.spectral_centroid is not None:
        if input.width is not None:
            conditions.append(func.abs(Sample.stereo_width - input.width) < 10)

        order_conditions.append(
            nullslast(
                func.abs(
                    (Sample.spectral_centroid * 0.5 + Sample.rolloff * 0.5)
                    - input.spectral_centroid
                ).asc()  # type: ignore[arg-type]
            )
        )
    if input.spectral_centroid is None and input.width is None:
        order_conditions.append(Sample.name.asc())

    # check if name is like
    def add_name_condition(text: str):
        return func.lower(Sample.name).like(f"%{text.lower()}%")

    # general metadata
    if input.name and input.name.strip():
        token_conditions = []
        matches = tokenize(input.name)
        for word in input.name.lower().split():
            if word not in matches:
                conditions.append(add_name_condition(word))

        for word in matches:
            token_conditions.append(add_name_condition(word))
        conditions.append(or_(*token_conditions))

    if input.is_favorite is True:
        conditions.append(Sample.is_favorite == True)
    if input.path is not None:
        conditions.append(
            or_(
                Sample.parent_path == str(input.path),
                Sample.path.contains(str(input.path)),
            )
        )

    samples = self.session.exec(
        select(Sample).where(*conditions).order_by(*order_conditions).limit(2000)
    ).all()
    return samples


def rescan_directory(db: Session, path: Path):
    child_samples = get_samples_by_directory(db, path)
    existing_samples = {sample.path: sample for sample in child_samples}

    valid_files = get_valid_files(path)

    for file in valid_files:
        if not file.is_file():
            continue
        matching_sample = existing_samples.get(str(file))
        rescan_sample(db, file, path, matching_sample)


def get_directory(db: Session, path: Path) -> Optional[Directory]:
    return db.exec(select(Directory).where(Directory.path == str(path))).first()


def delete_directory(db: Session, path: str):
    dir = db.exec(select(Directory).where(Directory.path == str(path))).first()

    if not dir:
        return None

    samples = get_samples_by_directory(db, Path(path))
    for s in samples:
        db.delete(s)

    db.delete(dir)
    db.commit()
    return dir


def create_directory(db: Session, path: Path) -> Directory:
    match get_directory(db, path):
        case None:
            pass
        case e:
            return e

    dir = Directory(path=str(path))
    db.add(dir)
    db.commit()
    db.refresh(dir)

    if dir is not None:
        new_thread = threading.Thread(
            target=rescan_directory, args=(path,), daemon=True
        )
        new_thread.start()

    return dir
