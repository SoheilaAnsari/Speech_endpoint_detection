# Speech Endpoint Detection

Endpoint detection for speech signals using **Short-Term Energy (STE)** and **Zero-Crossing Rate (ZCR)**. The implementation handles single words as well as multi-word utterances in both Persian and English, and includes a refinement step that prevents Persian words with weak fricatives (like *سعید* or *آفتاب*) from being incorrectly split into multiple words.

---

## The problem

Before any speech recognition pipeline can do useful work, it needs to know *where* the speech actually is inside a recording — separating the spoken segments from the surrounding silence and background noise. Getting this wrong is costly: misplaced boundaries either chop off real speech or feed extra noise into downstream stages, hurting both accuracy and computation time.

## The approach

Two classical features, used together:

- **Short-Term Energy (STE)** — speech frames carry noticeably more energy than silence frames. A raw boundary search is done using an upper and a lower energy threshold (ITU and ITL), derived from the statistics of the first 100 ms of the recording (assumed to be silence).
- **Zero-Crossing Rate (ZCR)** — refines the boundaries found by STE. Unvoiced fricatives (like the *f* in *آفتاب*) have low energy but very high ZCR, so the algorithm looks 6 frames before the raw start and 6 frames after the raw end, extending the boundaries if ZCR crosses its threshold.

A `syllable_threshold` parameter then checks whether two detected words are close enough that they should be merged into one — this is what keeps words like *سعید* from being incorrectly returned as two separate utterances.

## Repository layout

```
speech-endpoint-detection/
├── src/
│   └── double_word_V1.m     # the endpoint detection algorithm
├── audio/                    # sample recordings used in the report and slides
└── docs/
    └── presentation.pptx     # course presentation
```

## Running the code

Requirements: **MATLAB** (tested on R2016+) with the Signal Processing Toolbox.

1. Open `src/double_word_V1.m` in MATLAB.
2. Set the input filename near the top:
   ```matlab
   voice_name = '1234.wav';
   ```
3. Make sure the audio file is on MATLAB's path (e.g., copy the file from `audio/` into your working directory, or `addpath('audio')`).
4. Run the script.

It will produce two figures:

- **Figure 1** — STE, ZCR, and the original waveform, with detected start (red) and end (green) boundaries overlaid.
- **Figure 2** — the cropped, concatenated speech segments.

The cropped signal is also written to `cropped_name.wav`.

### Tunable parameters

The defaults work well for clean recordings made on a laptop microphone, but you can adjust them at the top of the script:

| Parameter | Default | What it controls |
|---|---|---|
| `max_words` | 10 | Maximum number of words to detect |
| `coef_ITL` | 16 | Multiplier for the lower energy threshold |
| `coef_ITU` | 64 | Multiplier for the upper energy threshold |
| `syllable_threshold` | 180 | Frame gap below which adjacent detections are merged into one word |
| `word_length` | 40 | Minimum word duration (in frames) |

## Sample audio

The `audio/` folder contains the recordings shown in the report and presentation:

- Single Persian words: `khobi.wav`, `payiz.wav`, `saeed.wav`, `soheila.wav`, `aftab.wav`
- Single English words: `two.wav`, `three.wav`, `five.wav`, `hello.wav`
- Multi-word utterance: `1234.wav`

## Results

The algorithm correctly detects endpoints for all English words tested and for most Persian words. The two trickier Persian cases — *سعید* (long internal vowel) and *آفتاب* (weak medial fricative) — are handled by the syllable-merging step; see the side-by-side results in the report (figures 2-4 and 2-5) showing the same word incorrectly split at `syllable_threshold=80` and correctly merged at `syllable_threshold=180`.

## References

Key works the implementation draws on:

- L. R. Rabiner and M. R. Sambur, "An algorithm for determining the endpoints of isolated utterances," *Bell System Technical Journal*, 1975.
- L. F. Lamel, L. R. Rabiner, A. E. Rosenberg, and J. G. Wilpon, "An improved endpoint detector for isolated word recognition," *IEEE Trans. ASSP*, vol. 29, no. 4, Aug. 1981.
- B. S. Atal and L. R. Rabiner, "A pattern recognition approach to voiced-unvoiced-silence classification with application to speech recognition," *IEEE Trans. ASSP*, vol. 24, June 1976.

## License

MIT — see [LICENSE](LICENSE).

