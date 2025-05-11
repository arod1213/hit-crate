from app.utils import db_to_amp


def amp_to_target_lufs(curr_lufs: float, target: float = -10.0) -> float:
    gain_db = target - curr_lufs
    return db_to_amp(gain_db)