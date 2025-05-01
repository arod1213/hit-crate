from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Optional

from sqlmodel import SQLModel


class AudioFormat(str, Enum):
    wav = ".wav"
    # aif = ".aif"
    mp3 = ".mp3"


@dataclass
class SampleSimilarInput:
    name: Optional[str] = None
    byWidth: bool = False
    byFreq: bool = True


class SampleQueryInput(SQLModel):
    is_favorite: Optional[bool] = None
    name: Optional[str] = None
    width: Optional[float] = None
    spectral_centroid: Optional[float] = None


class SampleCreateInput(SQLModel):
    path: Path
    parent_path: Path
    format: AudioFormat
    duration: Optional[float] = None
    hash: str
    sample_rate: int
    lufs: float
    stereo_width: float
    mfcc: bytes
    spectral_centroid: float


class SampleUpdateInput(SQLModel):
    is_favorite: Optional[bool] = None
    format: Optional[AudioFormat] = None
    duration: Optional[float] = None
    hash: Optional[str] = None
    sample_rate: Optional[int]
    lufs: Optional[float]
