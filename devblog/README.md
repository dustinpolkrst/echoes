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
3. For commits that have `shot.lua` next to `main.lua`, wraps it so the extra scenarios in `tools/blogscenarios.lua` (`pausesettings`, `titleup`, `quitonce`, `padhints`) resolve as `--shot` targets. This changes only the exported copy. From `7ae145b` on, `shot.lua` lives in `game/dev/` and the scenarios use the old flat `require` names, so these four targets work only for commits up to `1afca9f`.
4. Runs `lovec.exe <commit> --shot ...` from the export's parent folder, because LÖVE wants a short relative game path.
5. Copies the PNG that LÖVE reports from `%APPDATA%/LOVE/blogshot-<commit>/` to `static/images/<post>/<name>.png`.

It ends with `diff_pair`, which runs a commit's own `--diff` on two shots that a post claims are pixel-identical, and fails if any pixel differs. It checks the two pause shots in `05-bench` with `af3114f`, and the level select before and after the folder move in `09-layout` with `eccb521`.

The script does not depend on where the game's Lua files live in the current checkout. It exports each commit whole and runs that commit's own code. Up to `1afca9f`, `main.lua` sits in the repository root. From `7ae145b` on it sits in `game/`, and the script runs `<commit>/game` instead. Both layouts are in the shot list: `09-layout` shoots `1afca9f` and `eccb521`.

`--shot` arguments differ by commit. `a72332d` supports `--shot N` and `--shot N F` (level N, or F frames of its scripted solution). From `86d2d95` on, `shot.lua` also accepts `title`, `pause [N]`, `select [cleared]`, `settings`, `clear [N]` and `transition`. Shots are deterministic from `b9d194a` on. Earlier commits draw random dust, so their shots differ a little between runs, while the player, echoes, and doors land in the same place every time. A full rerun at `eccb521` reproduced the 21 shots from `b9d194a` or later byte for byte. It changed the 20 older shots in `01-pitch`, `03-puzzles`, and `04-interface`, which were restored with `git checkout` instead of committed.

After regenerating, look at every changed image before you commit it. A caption describes what a specific frame shows.

## Add a post

1. Create `content/posts/NN-slug.md` with this front matter:

       ---
       title: "Sentence-case title"
       description: "One or two sentences for the post list."
       part: 10
       weight: 10
       date: 2026-10-17
       commits: ["abc1234"]
       cover: "images/10-slug/some-shot.png"
       ---

   `weight` sets the order on the home page and the previous and next links.
2. Add the shots to the list in `tools/shots.sh` with the post folder `10-slug`, run `bash devblog/tools/shots.sh 10-slug`, and view each image.
3. Use the shortcodes in the post:

       {{< figure src="images/10-slug/some-shot.png" caption="What this frame shows." >}}

       {{< pair >}}
       {{< figure src="images/10-slug/before.png" caption="Before." >}}
       {{< figure src="images/10-slug/after.png" caption="After." >}}
       {{< /pair >}}

4. Run `bash devblog/tools/check-images.sh` and `hugo --source devblog`. Both should finish with no errors and no warnings.

Every number in a post should come from a commit message, the project brief, or a measurement you ran and can name.
