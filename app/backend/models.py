from __future__ import annotations

from datetime import datetime
from typing import List, Optional

from sqlalchemy import (
    BLOB,
    Boolean,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
)
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .schemas import AudioFormat

Base = declarative_base()


class Directory(Base):
    __tablename__ = "directory"

    path: Mapped[str] = mapped_column(String, primary_key=True)

    # Relationship to Sample
    samples: Mapped[List["Sample"]] = relationship(
        "Sample", back_populates="parent_directory"
    )


class Sample(Base):
    __tablename__ = "sample"
    __table_args__ = (
        Index("ix_sample_parent_path", "parent_path"),
        Index("ix_sample_is_favorite", "is_favorite"),
        Index("ix_sample_parent_path_is_favorite", "parent_path", "is_favorite"),
        Index("ix_sample_stereo_width", "stereo_width"),
        Index("ix_sample_spectral_centroid", "spectral_centroid"),
        Index("ix_sample_rolloff", "rolloff"),
    )

    path: Mapped[str] = mapped_column(String, primary_key=True)
    name: Mapped[str] = mapped_column(String, nullable=False)
    modified_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    hash: Mapped[str] = mapped_column(String, nullable=False)

    duration: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    format: Mapped[AudioFormat] = mapped_column(Enum(AudioFormat), nullable=False)

    is_favorite: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    sample_rate: Mapped[int] = mapped_column(Integer, nullable=False)
    lufs: Mapped[float] = mapped_column(Float, nullable=False)
    stereo_width: Mapped[float] = mapped_column(
        Float, nullable=False
    )  # value between 0 and 200
    mfcc: Mapped[bytes] = mapped_column(BLOB, nullable=False)
    spectral_centroid: Mapped[float] = mapped_column(Float, nullable=False)
    rolloff: Mapped[float] = mapped_column(Float, nullable=True, default=0.0)

    # Foreign key to directory table
    parent_path: Mapped[str] = mapped_column(String, ForeignKey("directory.path"))

    # Relationship to Directory
    parent_directory: Mapped["Directory"] = relationship(
        "Directory", back_populates="samples"
    )
