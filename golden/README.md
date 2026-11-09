# Golden frames

`scripts/golden-frames.py` plays a level with the game's `--shot` mode and diffs that PNG against a committed reference. The capture is the lossless PNG LÖVE writes. It is not a screen grab.

```
python3 scripts/golden-frames.py --style baseline
```

`--style` picks the directory `golden/<style>`. `baseline` is the no-flag look: the script runs `love game --shot LEVEL FRAME` and passes nothing else. `cutout` is a name the script accepts so that look can be added later. No Cutout references are committed. A style other than `baseline` fails without launching the game, and the script does not invent a style flag.

Each reference is one simulation frame of the nominal solution tape. The frame count is the `--shot` argument: that many `Scenes.update` steps, then one capture. Time is that count divided by 60.

The compare fails when any pixel's largest channel delta is above the tolerance in `scripts/golden-frames.py`. The tolerance is 0. A second capture of the same `--shot` on this machine matched the first PNG byte for byte. The shot path seeds both random generators, steps a fixed 1/60 clock, and encodes PNG without loss, so a nonzero channel delta is a different pixel. A wider tolerance would let a one-pixel render change pass.

References are refreshed on purpose after a content change. A red result once a level, a solution tape, or a draw path has changed is a stale reference, not by itself a render regression. When a content change lands, including the Underfoot redesign on PR #3, recapture the frames this manifest names and commit the new PNGs in the same change that should keep them. Do not treat that failure as proof the renderer broke.

The manifest next to the PNGs records the level, the frame, the style, and the base commit for each reference, and the moments this tape cannot produce.
