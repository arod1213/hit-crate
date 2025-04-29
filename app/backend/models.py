from __future__ import annotations

import datetime
from typing import Optional, Sequence

from sqlalchemy.types import BLOB
from sqlmodel import Column, Field, Relationship, SQLModel

from .schemas import AudioFormat


class Directory(SQLModel, table=True):
    path: str = Field(primary_key=True)

    # relationship
    samples: Sequence['Sample'] = Relationship(back_populates="parent_directory")


class Sample(SQLModel, table=True):
    path: str = Field(primary_key=True)
    modified_at: datetime.datetime
    duration: Optional[float] = None
    format: AudioFormat
    name: str
    hash: str
    sample_rate: int
    rms: float
    stereo_width: float  # value between 0 and 200
    mfcc: bytes = Field(default=None, sa_column=Column(BLOB))
    spectral_centroid: float

    # relationship
    parent_path: str = Field(foreign_key="directory.path")
    parent_directory: 'Directory' = Relationship(back_populates="samples")



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
