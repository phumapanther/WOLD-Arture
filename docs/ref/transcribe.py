# ponytail: one-off reel transcriber. usage: python transcribe.py <media> [lang]
import os, sys
os.environ.setdefault('KMP_DUPLICATE_LIB_OK', 'TRUE')
from faster_whisper import WhisperModel, decode_audio   # import before numpy (ctranslate2/OpenMP abort otherwise)
model = WhisperModel('mobiuslabsgmbh/faster-whisper-large-v3-turbo', device='cpu', compute_type='int8')
import numpy as np
src = sys.argv[1]; lang = sys.argv[2] if len(sys.argv) > 2 else None
audio = np.ascontiguousarray(decode_audio(src, sampling_rate=16000), dtype=np.float32)
segs, info = model.transcribe(audio, language=lang, vad_filter=True, beam_size=5)
out = open(os.path.splitext(src)[0] + '_transcript.txt', 'w', encoding='utf-8')
out.write(f'# lang={info.language} p={info.language_probability:.2f} dur={len(audio)/16000:.0f}s\n')
for s in segs:
    line = f'[{s.start:6.1f}-{s.end:6.1f}] {s.text.strip()}'
    print(line, flush=True); out.write(line + '\n')
