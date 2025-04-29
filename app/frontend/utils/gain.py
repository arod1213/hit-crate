def db_to_target_rms(rms: float, target: float = -6.0):
    # Target loudness
    gain_db = target - rms
    gain_linear = 10 ** (gain_db / 20)
    return gain_linear
