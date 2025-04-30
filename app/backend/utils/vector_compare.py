from concurrent.futures import ProcessPoolExecutor, ThreadPoolExecutor
from dataclasses import dataclass
from typing import Sequence

import numpy as np
from itertools import repeat

from app.backend.models import Sample
from app.backend.utils.to_bytes import bytes_to_array
from app.backend.utils.vector_analysis import dtw_similarity


@dataclass
class AudioMetadata:
    name: str
    mfcc: np.ndarray
    spectral_centroid: float


def sample_to_class(x: Sample):
    mfcc = bytes_to_array(x.mfcc)
    spectral_centroid = x.spectral_centroid
    return AudioMetadata(x.name, mfcc, spectral_centroid)


def score_sample(x: AudioMetadata, sample: Sample):
    y = sample_to_class(sample)

    if x.mfcc.shape == y.mfcc.shape:
        if (x.mfcc == y.mfcc).all():
            return (sample, 1.0)

    score = similarity_score(x, y)

    if score > 0.9:
        return (sample, score)
    return None


def sort_by_freq(x: Sample, samples: Sequence[Sample]) -> Sequence[Sample]:
    match = sample_to_class(x)

    with ThreadPoolExecutor(max_workers=5) as executor:
        results = list(filter(None, executor.map(score_sample, repeat(match), samples)))

    results.sort(key=lambda item: item[1], reverse=True)
    return [sample for sample, _ in results]


def similarity_score(x: AudioMetadata, y: AudioMetadata):
    mfcc = dtw_similarity(x.mfcc, y.mfcc)
    return mfcc
