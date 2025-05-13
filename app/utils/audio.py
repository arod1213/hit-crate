import numpy as np


def amp_to_db(amplitude, reference=1.0):
    """
    Convert amplitude to decibels (dB)

    Parameters:
    amplitude : float or numpy array
        The amplitude value(s) to convert
    reference : float, optional
        Reference amplitude (default: 1.0)

    Returns:
    float or numpy array
        The amplitude in dB
    """
    # Avoid log of zero or negative values
    with np.errstate(divide="ignore", invalid="ignore"):
        # Formula: dB = 20 * log10(amplitude/reference)
        db = 20 * np.log10(np.abs(amplitude) / reference)

        # Replace -inf (result of log10(0)) with very low dB
        if isinstance(db, np.ndarray):
            db = np.where(np.isinf(db), -120.0, db)
        elif np.isinf(db):
            db = -120.0

    return db


def db_to_amp(db, reference=1.0):
    """
    Convert decibels (dB) to amplitude

    Parameters:
    db : float or numpy array
        The decibel value(s) to convert
    reference : float, optional
        Reference amplitude (default: 1.0)

    Returns:
    float or numpy array
        The amplitude value(s)
    """
    # Formula: amplitude = reference * 10^(dB/20)
    return reference * (10 ** (db / 20.0))
