import io

import numpy as np


def array_to_bytes(arr: np.ndarray) -> bytes:
    buffer = io.BytesIO()
    # Save the array to the buffer as a .npy file (binary format)
    np.save(buffer, arr)
    buffer.seek(0)  # Go back to the start of the buffer after saving
    return buffer.read()  # Return the byte data


def bytes_to_array(byte_data: bytes) -> np.ndarray:
    buffer = io.BytesIO(byte_data)
    return np.load(buffer)
