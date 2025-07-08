from pathlib import Path

import numpy as np
from app.backend.utils.audio.get_details import AudioDetail

FILE_A = Path.home() / "Desktop" / "Scan Test" / "F.wav"
FILE_B = Path.home() / "Desktop" / "Scan Test" / "B.wav"
FILE_C = Path.home() / "Desktop" / "Scan Test" / "A.wav"

SAMPLE_FOLDER = Path.home() / "Documents" / "Sample Libraries" / "M-Phazes Drums and Samples" / "_!Beat Butcha Kits"

# @benchmark
# def scan():
    # with Session(engine) as session:
    #     DirectoryService(session).create(SAMPLE_FOLDER)
    # with Session(engine) as session:
    #     DirectoryService(session).rescan(SAMPLE_FOLDER)
#
# def delete():
#     pass
#     with Session(engine) as session:
#         DirectoryService(session).delete(str(SAMPLE_FOLDER))
# scan()
# delete()



files = [FILE_A, FILE_B, FILE_C]
for f in files:
    info = AudioDetail(f)
    print(f.name)
    # print("zero - ", info.zero_crossing)
    print("onset", info.onset_strength, info.decay_strength)
    # audio, sr = load_audio(str(f))
    # print(len(audio), sr)
    # detail = AudioDetail(f)
    # meta = AudioMeta(f)
