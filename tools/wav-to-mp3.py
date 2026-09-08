# Converts the synthesised WAVs to MP3, which is what Roblox accepts for audio uploads.
# Uses PyAV (FFmpeg's libraries) rather than a separate ffmpeg binary, since this machine has no ffmpeg
# and installers are blocked by policy. (PyAV here ships "vorbis" and "libmp3lame" but not "libvorbis";
# mp3 is the better-supported upload format anyway.)
import sys, wave
from pathlib import Path
import numpy as np
import av

def convert(src: Path, dst: Path, bitrate=192000):
    with wave.open(str(src)) as w:
        sr = w.getframerate()
        pcm = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2")

    out = av.open(str(dst), "w")
    stream = out.add_stream("libmp3lame", rate=sr)
    # Force mono: without this the encoder upmixes to stereo and doubles the file for no benefit --
    # these are point-source game sounds that Roblox positions in 3D itself.
    stream.layout = "mono"
    stream.bit_rate = bitrate
    # The encoder wants planar float; hand it one frame and let it chunk internally.
    frame = av.AudioFrame.from_ndarray(
        (pcm.astype(np.float32) / 32768.0).reshape(1, -1), format="fltp", layout="mono")
    frame.rate = sr
    for packet in stream.encode(frame):
        out.mux(packet)
    for packet in stream.encode(None):
        out.mux(packet)
    out.close()
    return dst.stat().st_size

src_dir, dst_dir = Path(sys.argv[1]), Path(sys.argv[2])
dst_dir.mkdir(parents=True, exist_ok=True)
for f in sorted(src_dir.glob("*.wav")):
    size = convert(f, dst_dir / f"{f.stem}.mp3")
    print(f"  {f.stem + '.mp3':24s} {size/1024:6.1f} KB")
