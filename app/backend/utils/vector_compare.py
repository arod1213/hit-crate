from dataclasses import dataclass
from typing import Sequence

import numpy as np

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


def sort_by_freq(x: Sample, samples: Sequence[Sample]) -> Sequence[Sample]:
    scored_matches = []
    match = sample_to_class(x)
    for sample in samples:
        if x == sample:
            scored_matches.append((sample, 1))
            continue

        y = sample_to_class(sample)
        score = similarity_score(match, y)

        if score > 0.9:
            scored_matches.append((sample, score))

    scored_matches.sort(key=lambda item: item[1], reverse=True)
    return [sample for sample, _ in scored_matches]


def similarity_score(x: AudioMetadata, y: AudioMetadata):
    mfcc = dtw_similarity(x.mfcc, y.mfcc)
    # print(f"{x.name} to {y.name}")
    # print(f"MFFC {mfcc}")
    # print(f"FUND {fundamental}")
    # print(f"Roloff {rolloff}")
    #
    # weights = [
    #     (mfcc, 2),
    #     (fundamental, 1),
    #     (rolloff, 2),
    # ]
    #
    # if fundamental == 0:
    #     weights = [
    #         (mfcc, 2),
    #         (fundamental, 0.2),
    #         (rolloff, 2),
    #     ]

    # score_sum = 0
    # weight_sum = sum(weight for _, weight in weights)
    #
    # for score, weight in weights:
    #     weight /= weight_sum
    #     score_sum += score * weight

    return mfcc
