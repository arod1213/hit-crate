def amp_to_target_lufs(curr: float, target: float = -10.0):
    gain_db = target - curr
    return 10 ** (gain_db / 20)
