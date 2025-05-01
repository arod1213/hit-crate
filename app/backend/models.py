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

    path: Mapped[str] = mapped_column(String, primary_key=True)
    name: Mapped[str] = mapped_column(String, nullable=False)
    modified_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    hash: Mapped[str] = mapped_column(String, nullable=False)

    duration: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    format: Mapped[AudioFormat] = mapped_column(
        Enum(AudioFormat), nullable=False
    )

    is_favorite: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False
    )

    sample_rate: Mapped[int] = mapped_column(Integer, nullable=False)
    lufs: Mapped[float] = mapped_column(Float, nullable=False)
    stereo_width: Mapped[float] = mapped_column(
        Float, nullable=False
    )  # value between 0 and 200
    mfcc: Mapped[bytes] = mapped_column(BLOB, nullable=False)
    spectral_centroid: Mapped[float] = mapped_column(Float, nullable=False)

    # Foreign key to directory table
    parent_path: Mapped[str] = mapped_column(
        String, ForeignKey("directory.path")
    )

    # Relationship to Directory
    parent_directory: Mapped["Directory"] = relationship(
        "Directory", back_populates="samples"
    )


# class Tag(SQLModel, table=True):
#     id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
#     name: str
#
#     # Relationship with the junction table
#     sample_tags: List["SampleTag"] = Relationship(back_populates="tag")
#
#
# class SampleTag(SQLModel, table=True):
#     id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
#
#     # relationships
#     sample_id: uuid.UUID = Field(foreign_key="sample.id")
#     sample: Sample = Relationship(back_populates="sample_tags")
#     tag_id: uuid.UUID = Field(foreign_key="tag.id")
#     tag: Tag = Relationship(back_populates="sample_tags")
