import os
from datetime import datetime
from pathlib import Path
from typing import Optional, Sequence

from sqlalchemy import func, nullslast, or_
from sqlmodel import Session, select

from app.backend.utils.tokenizer import tokenize

from ..models import Sample
from ..schemas import (
    SampleCreateInput,
    SampleQueryInput,
    SampleSimilarInput,
    SampleUpdateInput,
    SampleUpdateMetaInput,
)
from ..utils.vector_compare import sort_by_freq


class SampleRepo:
    def __init__(self, session: Session):
        self.session = session

    def query(self, path: Path) -> Optional[Sample]:
        return self.session.exec(select(Sample).where(Sample.path == str(path))).first()

    def query_by_parent(self, path: Path):
        return self.session.exec(
            select(Sample).where(
                or_(
                    Sample.parent_path == str(path),
                    Sample.path.contains(str(path)),
                )
            )
        ).all()

    def query_samples(self, input: SampleQueryInput) -> Sequence[Sample]:
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

    def query_similar(
        self,
        path: Path,
        input: SampleSimilarInput,
    ) -> Sequence[Sample]:
        found = self.session.exec(
            select(Sample).where(Sample.path == str(path))
        ).first()
        if not found:
            return []
        conditions = []
        if found.stereo_width is not None and input.byWidth:
            conditions.append(Sample.stereo_width is not None)
            conditions.append(func.abs(Sample.stereo_width - found.stereo_width) < 8)  # type: ignore[arg-type]

        matches = self.session.exec(
            select(Sample)
            .where(*conditions)
            .order_by(
                nullslast(
                    func.abs(Sample.stereo_width - found.stereo_width).asc()  # type: ignore[arg-type]
                )
            )
        ).all()

        if input.byFreq:
            matches = sort_by_freq(found, matches)

        return matches

    def create(self, input: SampleCreateInput) -> Sample:
        existing = self.session.exec(
            select(Sample).where(Sample.path == str(input.path))
        ).first()

        if existing:
            return existing

        m_time_float = os.path.getmtime(input.path)
        sample = Sample(
            name=input.path.stem,
            path=str(input.path),
            parent_path=str(input.parent_path),
            modified_at=datetime.fromtimestamp(m_time_float),
            format=input.format,
            duration=input.duration,
            hash=input.hash,
            sample_rate=input.sample_rate,
            lufs=input.lufs,
            stereo_width=input.stereo_width,
            mfcc=input.mfcc,
            spectral_centroid=input.spectral_centroid,
            rolloff=input.rolloff,
        )

        self.session.add(sample)
        self.session.commit()
        self.session.refresh(sample)
        return sample

    def update(self, path: Path, input: SampleUpdateInput | SampleUpdateMetaInput) -> Optional[Sample]:
        sample = self.session.exec(
            select(Sample).where(Sample.path == str(path))
        ).first()
        if not sample:
            return

        m_time_float = os.path.getmtime(path)
        sample.modified_at = datetime.fromtimestamp(m_time_float)

        for attr in dir(input):
            if not attr.startswith("_") and hasattr(sample, attr):
                value = getattr(input, attr)
                if value is not None:
                    # print(f"{attr} - {value}")
                    setattr(sample, attr, value)

        self.session.add(sample)
        self.session.commit()
        self.session.refresh(sample)

        return sample

    def update_path(self, src_path: Path, dest_path: Path):
        sample = self.session.exec(
            select(Sample).where(Sample.path == str(src_path))
        ).first()
        if not sample:
            return
        sample.path = str(dest_path)
        sample.name = dest_path.stem

        self.session.add(sample)
        self.session.commit()
        self.session.refresh(sample)

    def delete(self, path: Path):
        sample = self.session.exec(
            select(Sample).where(Sample.path == str(path))
        ).first()

        if not sample:
            return None
        self.session.delete(sample)
        self.session.commit()
        return sample
