# Echoes dev blog

A Hugo site that tells how Echoes was built, one post per milestone. The theme is local: `layouts/` and `static/css/site.css`. It needs Hugo 0.145 extended and nothing else.

## Preview

From the repository root:

    hugo server --source devblog

Open the printed address. To build static files into `devblog/public/`:

    hugo --source devblog

## Check the images

    bash devblog/tools/check-images.sh

The script fails if a post references an image that does not exist, if a PNG in `static/images/` is not used by any page, or if a built page has an `<img>` whose file is missing from the output. The `figure` shortcode also stops the build when its `src` is missing.

## Regenerate the screenshots

    bash devblog/tools/shots.sh            # every shot
    bash devblog/tools/shots.sh 06-review  # only one post folder

Requirements: Git Bash, and LÖVE 11.5 at `C:/Program Files/LOVE/lovec.exe` (set `LOVE=...` to use another path).

`tools/shots.sh` holds the shot list: post folder, commit, output name, and `--shot` arguments. For each commit it:

1. Exports the tree with `git archive` into `%TEMP%/echoes-blogshots/<commit>`.
2. Rewrites `t.identity` in that copy's `conf.lua` to `blogshot-<commit>`, and refuses to run if the rewrite did not take. The identity `echoes` holds the player's real save and is never used.
3. For commits that have `shot.lua`, wraps it so the extra scenarios in `tools/blogscenarios.lua` (`pausesettings`, `titleup`, `quitonce`, `padhints`) resolve as `--shot` targets. This changes only the exported copy.
4. Runs `lovec.exe <commit> --shot ...` from the export's parent folder, because LÖVE wants a short relative game path.
5. Copies the PNG that LÖVE reports from `%APPDATA%/LOVE/blogshot-<commit>/` to `static/images/<post>/<name>.png`.

It ends by running `af3114f`'s `--diff` on the two pause shots in `05-bench`, which the post claims are pixel-identical.

The script does not depend on where the game's Lua files live in the current checkout. It exports each commit whole and runs that commit's own code. If a commit keeps `main.lua` in a `game/` folder instead of the root, the script runs `<commit>/game`.

`--shot` arguments differ by commit. `a72332d` supports `--shot N` and `--shot N F` (level N, or F frames of its scripted solution). From `86d2d95` on, `shot.lua` also accepts `title`, `pause [N]`, `select [cleared]`, `settings`, `clear [N]` and `transition`. Shots are deterministic from `b9d194a` on. Earlier commits draw random dust, so their shots differ a little between runs, while the player, echoes, and doors land in the same place every time. A full rerun reproduced the 15 shots from `b9d194a` or later byte for byte.

After regenerating, look at every changed image before you commit it. A caption describes what a specific frame shows.

## Add a post

1. Create `content/posts/NN-slug.md` with this front matter:

       ---
       title: "Sentence-case title"
       description: "One or two sentences for the post list."
       part: 9
       weight: 9
       date: 2026-10-17
       commits: ["abc1234"]
       cover: "images/09-slug/some-shot.png"
       ---

   `weight` sets the order on the home page and the previous and next links.
2. Add the shots to the list in `tools/shots.sh` with the post folder `09-slug`, run `bash devblog/tools/shots.sh 09-slug`, and view each image.
3. Use the shortcodes in the post:

       {{< figure src="images/09-slug/some-shot.png" caption="What this frame shows." >}}

       {{< pair >}}
       {{< figure src="images/09-slug/before.png" caption="Before." >}}
       {{< figure src="images/09-slug/after.png" caption="After." >}}
       {{< /pair >}}

4. Run `bash devblog/tools/check-images.sh` and `hugo --source devblog`. Both should finish with no errors and no warnings.

Every number in a post should come from a commit message, the project brief, or a measurement you ran and can name.
