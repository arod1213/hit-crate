import pytest

from app.backend.scan.valid import get_valid_files  # adjust path as needed


@pytest.fixture
def setup_test_dir(tmp_path):
    # Create valid audio files
    valid_files = [
        tmp_path / "song1.mp3",
        tmp_path / "song2.WAV",  # uppercase test
        tmp_path / "album" / "track1.mp3",
    ]
    (tmp_path / "album").mkdir()
    for f in valid_files:
        f.touch()

    # Create invalid files
    invalid_files = [
        tmp_path / "notes.txt",
        tmp_path / "image.png",
        tmp_path / "album" / "track2.docx",
    ]
    for f in invalid_files:
        f.touch()

    return tmp_path, valid_files, invalid_files


def test_get_valid_files(setup_test_dir):
    test_dir, valid_files, _ = setup_test_dir
    expected_paths = {f.resolve() for f in valid_files}

    result = {f.resolve() for f in get_valid_files(test_dir)}

    assert result == expected_paths


def test_get_invalid_files(setup_test_dir):
    test_dir, _, invalid_files = setup_test_dir
    result = list(get_valid_files(test_dir))
    for f in invalid_files:
        assert f not in result


def test_empty_directory(tmp_path):
    result = list(get_valid_files(tmp_path))
    assert result == []
