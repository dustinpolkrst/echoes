# Assets

Drop files here and the game uses them. A slot with no file keeps its built-in procedural art or generated sound, so an empty folder plays exactly like the original. Files are found in this folder or in the LÖVE save directory (`%APPDATA%/LOVE/echoes/assets/...`). Restart to pick up changes, or call `require('assets').reload()` (F5 if the game binds it). Files that match no slot are reported in the console.

## Sprites: `assets/sprites/<slot>.png`

All sprites draw with nearest-neighbour filtering at game resolution (480x270, scaled 2x), so 1 image pixel is 1 game pixel.

A PNG whose width is a multiple of its height is a horizontal strip of square frames. Otherwise it is one frame. An optional `<slot>.lua` returns `{ frameW =, frameH =, fps =, ox =, oy = }` for other frame sizes (frames are read left to right, then top to bottom), a different speed, or a different origin. `ox`, `oy` are the point inside a frame that sits on the anchor below.

| Slot | Frame size | Anchor and frames |
| --- | --- | --- |
| `player` | 16x16 | Feet at the bottom centre of the 10x12 hitbox. Animated at 8 fps. Draw it facing right, it is flipped for left. The game squashes and stretches it. |
| `echo` | 16x16 | Same as `player`. The game tints it cyan, or violet for a mirrored echo, and fades it. Absent means the procedural ghost, even if `player` exists. |
| `solid` | 16x16 | Top-left of the cell. A strip is a set of variants, one picked per cell by hash. No edge or neighbour logic. |
| `oneway` | 16x16 | Top-left of the cell. Variants like `solid`. The collision surface is the top 5 rows, so draw the platform there. |
| `spike` | 16x16 | Top-left of the cell. Animated at 6 fps. The hurt box is the lower half. |
| `plate` | 16x16 | Top-left of the cell. Frame 1 idle, frame 2 pressed. Draw it white or grey, the game multiplies it by the plate colour (cyan, pink, yellow, green). The pressed surface is the bottom 4 rows. |
| `door` | 16x16 | One cell, repeated down the door and cropped from the bottom as it opens. Animated at 6 fps. Tinted by plate colour like `plate`. |
| `goal` | 16x16 | Top-left of the cell. Animated at 8 fps. |
| `torch` | 16x16 | Top-left of the cell. Animated at 8 fps. Replaces the chain and flame. |
| `mirror` | 16x16 | Top-left of the cell. Animated at 8 fps. The shrine the player touches to cast a mirrored echo; the procedural one overhangs the cell above. |
| `veil` | 16x16 | Top-left of the cell. Animated at 8 fps. Drawn over the background with alpha; echoes halt at it and the player walks through. |
| `crumble` | 16x16 | Top-left of the cell. Frame 1 intact, frame 2 cracking, frame 3 gone. |
| `bg_far` | 480x270 or wider | Replaces the sky gradient. Tiles horizontally at parallax 0.05, fixed vertically. Make it opaque. |
| `bg_mid` | 480x270 or wider | Replaces the arches. Parallax 0.12, hangs from the bottom edge. Use transparency. |
| `bg_near` | 480x270 or wider | Replaces the hanging vines. Parallax 0.35, hangs from the top edge. Use transparency. |

Lighting, glows, motes and the HUD are drawn over everything, so sprites are lit like the procedural art.

## Sounds: `assets/sfx/<slot>.ogg`, `.wav` or `.mp3`

Looked up in that order. Sounds are loaded as static sources and played at the game volume.

| Slot | When | Notes |
| --- | --- | --- |
| `jump` | Jump | |
| `land` | Landing | Played at pitch 0.9 to 1.2 by impact speed. |
| `cast` | Cast an echo | |
| `plate` | Plate pressed or released | Pitch 1.0 pressed, 0.8 released. |
| `door` | Door opens or closes | Pitch 1.0 open, 0.85 close. |
| `death` | Player dies | |
| `goal` | Level cleared | |
| `crumble` | Crumble stone collapses or regrows | Pitch 1.0 collapse, 1.4 regrowth. |
