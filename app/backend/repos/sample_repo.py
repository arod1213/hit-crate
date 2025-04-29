import os
from datetime import datetime
from pathlib import Path
from typing import Sequence
import math

from sqlalchemy import func, nullslast
from sqlmodel import Session, select

from ..models import Sample
from ..schemas import (
    SampleCreateInput,
    SampleQueryInput,
    SampleSimilarInput,
    SampleUpdateInput,
)
from ..utils.vector_compare import sort_by_freq


class SampleRepo:
    def __init__(self, session: Session):
        self.session = session

    def query(self, path: Path):
        return self.session.exec(
            select(Sample).where(Sample.path == str(path))
        ).first()

    def query_samples(self, input: SampleQueryInput) -> Sequence[Sample]:
        conditions = []
        order_conditions = []

        if input.path:
            conditions.append(Sample.path == input.path)
        if input.width:
            conditions.append(Sample.stereo_width is not None)
            conditions.append(
                func.abs(Sample.stereo_width - input.width)
                < 5  # type: ignore[arg-type]
            )
        if input.spectral_centroid is not None:
            order_conditions.append(
                nullslast(
                    func.abs(
                        Sample.spectral_centroid - input.spectral_centroid
                    ).asc()  # type: ignore[arg-type]
                )
            )
            conditions.append(
                func.abs(
                    func.log(Sample.spectral_centroid)
                    - func.log(input.spectral_centroid)
                )
                < 0.3
            )
            pass
        if input.name and input.name != "":
            conditions.append(
                func.lower(Sample.path).like(f"%{input.name.lower()}%")
            )

        samples = self.session.exec(
            select(Sample)
            .where(*conditions)
            .order_by(*order_conditions)
            .limit(1000)
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
            conditions.append(
                func.abs(Sample.stereo_width - found.stereo_width) < 8
            )  # type: ignore[arg-type]

        matches = self.session.exec(
            select(Sample)
            .where(*conditions)
            .order_by(
                nullslast(
                    func.abs(
                        Sample.stereo_width - found.stereo_width
                    ).asc()  # type: ignore[arg-type]
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
            modified_at=datetime.fromtimestamp(m_time_float),
            format=input.format,
            duration=input.duration,
            hash=input.hash,
            sample_rate=input.sample_rate,
            rms=input.rms,
            stereo_width=input.stereo_width,
            mfcc=input.mfcc,
            spectral_centroid=input.spectral_centroid,
        )

        self.session.add(sample)
        self.session.commit()
        self.session.refresh(sample)
        return sample

    def update(self, path: Path, input: SampleUpdateInput):
        sample = self.session.exec(
            select(Sample).where(Sample.path == str(path))
        ).first()
        if not sample:
            return

        m_time_float = os.path.getmtime(path)
        sample.modified_at = datetime.fromtimestamp(m_time_float)
        if input.hash is not None:
            sample.hash = input.hash
            sample.duration = input.duration
        if input.rms is not None:
            sample.rms = input.rms
        if input.sample_rate is not None:
            sample.sample_rate = input.sample_rate

        self.session.add(sample)
        self.session.commit()
        self.session.refresh(sample)

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
