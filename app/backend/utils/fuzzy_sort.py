from typing import Sequence

from thefuzz import process

from app.backend.models import Sample


def fuzzy_sort(name: str, samples: Sequence[Sample]):
    name_to_sample = {sample.name: sample for sample in samples}
    matches = process.extract(
        name,
        name_to_sample.keys(),
        limit=100,
        # scorer=fuzz.ratio,
    )

    return [
        name_to_sample[file_name] for file_name, score in matches if score > 70
    ]
