# Puzzle Difficulty Folders Checklist

Source design doc: `docs/design/puzzle-difficulty-folders.md` (both open questions
resolved therein — do not re-litigate). Each item below is independently
completable by a fresh agent using this checklist item plus the design doc.

- [x] Task A — `assets/puzzles/1.png`, `2.png`, `3.png` → `assets/puzzles/easy/1.png`, `2.png`, `3.png`. **(parallel-safe)**
  - Current state: `assets/puzzles/1.png`/`2.png`/`3.png` are tracked, top-level,
    651/595/670 bytes. `assets/puzzles/easy/1.png`/`2.png`/`3.png` already exist
    on disk but are **untracked** and are near-duplicates of different byte size
    (602/1658/1410 bytes) — redundant files of unknown provenance per the
    design doc's Open Question 1 resolution.
  - Because `assets/puzzles/easy/{1,2,3}.png` already exist as untracked files,
    `git mv` cannot target those paths directly (git mv refuses to overwrite an
    existing file, tracked or not). Sequence it as:
    1. `rm assets/puzzles/easy/1.png assets/puzzles/easy/2.png assets/puzzles/easy/3.png`
       (removes the untracked near-duplicates).
    2. `git mv assets/puzzles/1.png assets/puzzles/easy/1.png`
    3. `git mv assets/puzzles/2.png assets/puzzles/easy/2.png`
    4. `git mv assets/puzzles/3.png assets/puzzles/easy/3.png`
  - Verify afterward: `git status` shows the three moves as renames (not a
    delete + untracked-add), `ls assets/puzzles/` shows no top-level `.png`
    files left, and `assets/puzzles/easy/` contains exactly `1.png`/`2.png`/`3.png`
    matching the original top-level files' byte sizes (651/595/670 bytes).
  - Do not touch `assets/puzzles/med/` or `assets/puzzles/hard/` in this task.

- [x] Task B — `assets/puzzles/med/1.png`, `assets/puzzles/hard/1.png`. **(parallel-safe)**
  - Both files already exist on disk, untracked. Per the design doc's Open
    Question 2 resolution, commit them as-is — no regeneration, no pixel
    changes.
  - Run `git add assets/puzzles/med/1.png assets/puzzles/hard/1.png`.
  - Verify afterward: `git status` shows both files staged as new additions,
    and the files are unmodified (`med/1.png` still 256x256 / 1777 bytes,
    `hard/1.png` still 320x320 / 3027 bytes — do not open/re-save them with any
    image tool).

- [x] Task C — delete `scripts/generate_puzzle_images.py`. **(parallel-safe)**
  - Per the design doc's Open Question 2 resolution: the script is no longer
    needed now that all 5 target images exist as real files (easy via Task A,
    med/hard via Task B). No replacement script is created.
  - Run `git rm scripts/generate_puzzle_images.py`.
  - Do not delete or modify any other file under `scripts/` (only touch this
    one file; if other files exist in that directory, leave them alone).

- [x] Task D — create `game/puzzle_catalog.lua` (new file). **(parallel-safe)**
  - Follow this codebase's existing small single-purpose module style/structure
    — see `game/jigsaw_solver.lua` and `game/spawn_button.lua` for precedent
    (local module table, `return M`/`return TableName` at the end, no OOP
    metatable needed here since this module has no instances).
  - Hardcode the 3 tier folder names as a local array: `{"easy", "med", "hard"}`
    (do not implement a generic recursive directory walk or use
    `love.filesystem.getInfo` — see design doc "What changes" / Open Question 3
    for why: `love.filesystem.getInfo` is hard-stubbed to always return `nil`
    in `lua/headless/stubs.lua`, and the tier set is small/fixed/known).
  - For each tier name, call
    `love.filesystem.getDirectoryItems("assets/puzzles/" .. tier)`, and for
    each returned entry ending in `.png` (use the same suffix-filter approach
    already used in `lua/headless/runner.lua:75-81` for `tests/*.lua`
    discovery), append `"assets/puzzles/" .. tier .. "/" .. filename` to one
    single flat array shared across all three tiers (no per-tier grouping/keys
    in the final structure — a plain array of path strings, e.g.
    `{"assets/puzzles/easy/1.png", "assets/puzzles/med/1.png", ...}`).
  - Memoize: the scan (the loop over tiers + `getDirectoryItems` calls) must
    run at most once per process. Cache the resulting flat array in a local
    (module-scope) variable on first computation; every subsequent call
    returns the cached array without re-scanning.
  - Expose the list via a function, e.g. `PuzzleCatalog.list()` — returns the
    (possibly newly computed, possibly cached) flat array of path strings.
  - Entries are plain path strings only — no `{number=..., path=...}` wrapper
    table (the old `PUZZLE_IMAGES` table's `number` field is confirmed unused
    elsewhere and is not carried over).
  - Module must not read/require `game/jigsaw_box.lua` or vice versa's contents
    beyond `jigsaw_box.lua` requiring this module (see Task E) — keep this
    module free of any box/piece-construction logic.

- [x] Task E — update `game/jigsaw_box.lua`. **(depends on: Task D)**
  - Add `local PuzzleCatalog = require("game/puzzle_catalog")` near the top
    (alongside the existing `require`s for `Sprite`, `JigsawPiece`, `C`).
  - Delete the hardcoded `PUZZLE_IMAGES` table (currently lines 5-9 — verify
    current line numbers before editing, they may have shifted):
    ```lua
    local PUZZLE_IMAGES = {
        { number = 1, path = "assets/puzzles/1.png" },
        { number = 2, path = "assets/puzzles/2.png" },
        { number = 3, path = "assets/puzzles/3.png" },
    }
    ```
  - In `JigsawBox.new`, replace:
    ```lua
    local puzzle_entry = PUZZLE_IMAGES[math.random(#PUZZLE_IMAGES)]
    local puzzle_image = love.graphics.newImage(puzzle_entry.path)
    ```
    with:
    ```lua
    local list = PuzzleCatalog.list()
    local path = list[math.random(#list)]
    local puzzle_image = love.graphics.newImage(path)
    ```
  - Everything after that line (`imgW, imgH = puzzle_image:getDimensions()`
    onward — grid-size inference, quad slicing, shuffle) is unchanged; do not
    modify it. There is no more `.path`/`.number` field access anywhere in this
    file after this edit — grep the file for `PUZZLE_IMAGES` and
    `puzzle_entry` afterward to confirm zero remaining references.

- [x] Task F — update `lua/headless/stubs.lua`'s `make_stub_image()`. **(parallel-safe)**
  - Currently (see comment above the function) it unconditionally returns a
    fixed 192x192 stub image regardless of arguments, and is installed as the
    catch-all factory for every `love.graphics.new*` call (including
    `newImage` and `newQuad`) via the metatable `__index` on `graphics_stub`.
  - Make the image dimensions path-aware so headless tests can exercise 4x4
    and 5x5 grid inference: change `make_stub_image` to accept a `path`
    parameter (the catch-all `__index` passes through whatever arguments the
    real call site used, e.g. `love.graphics.newImage(path)` — confirm the
    metatable wiring at the bottom of the file still forwards args correctly;
    it currently returns the bare `make_stub_image` function reference as the
    factory, which Lua will call with the same args the real `new*` call
    received).
  - Logic: if `path` (string) contains `/med/`, return 256x256; if it contains
    `/hard/`, return 320x320; otherwise (covers `/easy/` and any other/no
    path, e.g. calls with no path argument such as `newQuad`) return 192x192 —
    i.e. keep 192x192 as the default/fallback so nothing that doesn't pass a
    `/med/`- or `/hard/`-containing path changes behavior.
  - Use plain substring matching (e.g. `path:find("/med/", 1, true)`), not a
    Lua pattern that could misinterpret `/` specially (`/` has no special
    meaning in Lua patterns, but prefer the plain-find form for clarity and to
    guard against nil `path`).
  - Guard against `path` being `nil` (e.g. other `new*` stub calls with no
    path argument, like `newQuad`) — must not error, must fall through to the
    192x192 default.
  - `getWidth`/`getHeight`/`getDimensions` on the returned stub table must all
    reflect the same chosen dimensions consistently (all three currently
    return hardcoded 192/192 independently — keep them consistent with
    whichever size is chosen).
  - Do not change `setFilter` or anything else about the stub's shape/fields,
    and do not change how `newQuad` or any other stub behaves (they're
    unaffected per the design doc — only `newImage`'s effective dimensions
    change based on path).

- [x] Task G — update `tests/test_jigsaw.lua`. **(depends on: Task A, Task B, Task D, Task E, Task F)**
  - This depends on the *real* asset layout (Task A/B) because the rewritten
    test calls the real, non-mocked `PuzzleCatalog.list()`, which performs an
    actual `love.filesystem.getDirectoryItems` scan of `assets/puzzles/easy/`,
    `med/`, `hard/` on disk (headless mode does not stub
    `love.filesystem.getDirectoryItems` — only `love.filesystem.getInfo` is
    stubbed, per `lua/headless/stubs.lua`) — so the expected path set in this
    test is only correct once the real folders are in their final state.
  - Add `local PuzzleCatalog = require("game/puzzle_catalog")` near the top of
    the file alongside the existing `require`s.
  - Locate the `do ... end` block starting around the comment
    `-- JigsawBox.new randomly selects one of the 3 puzzle images ----` (was
    lines ~547-595 as of the design doc; verify current line numbers). Replace
    the hardcoded `expected_paths` table (currently the 3 literal
    `"assets/puzzles/1.png"`/`2.png`/`3.png"` keys) with a set built from
    `PuzzleCatalog.list()`, e.g.:
    ```lua
    local expected_paths = {}
    for _, path in ipairs(PuzzleCatalog.list()) do
        expected_paths[path] = true
    end
    ```
  - Keep the existing spy-and-restore pattern on `love.graphics.newImage`
    (real function saved, spy installed, `JigsawBox.new(128, 128)` called 10
    times in a loop, spy restored) and the two existing assertions (all 10
    captured paths are in `expected_paths`; not all 10 captured paths are
    identical, i.e. some variety) — only the *source* of `expected_paths`
    changes, not the surrounding mechanics. Note: with a 5-image catalog
    (3 easy + 1 med + 1 hard) instead of 3, "not all identical across 10
    trials" is still an overwhelmingly safe probabilistic assertion — no
    change needed to the trial count or the all-same check itself.
  - Add a new test (new `do ... end` block) asserting flat-uniform selection
    across the *whole* catalog, not per-tier-then-per-image: run enough trials
    (follow the existing convention in this file for probabilistic/statistical
    checks — e.g. hundreds of trials, similar order of magnitude to existing
    shuffle-order/rotation-step variety checks elsewhere in this file) capturing
    `love.graphics.newImage` paths via the same spy pattern, then assert that
    every path in `PuzzleCatalog.list()` (all 5, across all 3 tiers) is hit at
    least once across the trials — this distinguishes flat-uniform (every one
    of 5 images ~20% each) from a per-tier-first scheme (which with today's 3/1/1
    folder counts would make the med and hard images individually far rarer
    than a flat scheme predicts, since a per-tier scheme would give med and
    hard each a 1/3 chance rather than 1/5). Use enough trials that a correct
    flat-uniform implementation passing this assertion is not a coincidence
    (e.g. large enough that the least-likely-under-flat-uniform image, 1/5 per
    trial, has negligible odds of being missed entirely — mirror the trial
    count structure of existing probabilistic tests in this file rather than
    inventing new statistical machinery).
  - Add a new test (or extend an existing grid-inference test) that
    constructs a `JigsawBox` whose `love.graphics.newImage` spy is forced (or
    whose catalog entry is confirmed) to resolve to the `med/1.png` path and
    asserts `box.cols == 4`, `box.rows == 4`, `box.piece_count == 16`; and
    another asserting `hard/1.png` → `box.cols == 5`, `box.rows == 5`,
    `box.piece_count == 25`. This only produces a meaningful assertion once
    Task F's path-aware stub is in place (256x256 for `/med/`, 320x320 for
    `/hard/`) — since `love.graphics.newImage` is stubbed in headless mode,
    the *dimensions* JigsawBox infers rows/cols from come from the stub, not
    the real PNG file, regardless of which real path was picked. If
    `math.random` selection makes it impractical to reliably land on a
    specific tier's image within a bounded number of trials, either loop
    until an image path containing `/med/` (respectively `/hard/`) is picked
    (bounded retry, consistent with the bounded-search style already used
    elsewhere in this codebase, e.g. `game/jigsaw_box.lua`'s slot search) or
    spy on `love.graphics.newImage` and force its returned image's dimensions
    directly for that one construction — pick whichever approach best matches
    this test file's existing conventions.
  - Do not modify any other test block in this file.

- [x] Task H — new test coverage for `game/puzzle_catalog.lua`. **(depends on: Task D)**
  - Either a new file `tests/test_puzzle_catalog.lua` or a new section within
    an existing appropriate test file — match this codebase's existing
    per-module test file convention (e.g. `tests/test_jigsaw.lua` covers
    `game/jigsaw_box.lua`/`jigsaw_piece.lua`/`jigsaw_solver.lua`); prefer a new
    `tests/test_puzzle_catalog.lua` file since `puzzle_catalog.lua` is its own
    module with no existing dedicated test file. If a new file is created, it
    will be auto-discovered by `lua/headless/runner.lua`'s `tests/*.lua` scan
    — no registration needed elsewhere.
  - This test does not depend on the real `assets/puzzles/` folder layout
    (Task A/B) — spy/mock `love.filesystem.getDirectoryItems` directly, the
    same spy-and-restore-real-function pattern already used in
    `tests/test_jigsaw.lua` for `love.graphics.newQuad`/`newImage` (save the
    real function, install a replacement, restore the real function
    afterward). Have the mock return fixed fake filenames per tier argument
    (e.g. `"assets/puzzles/easy"` → `{"1.png", "2.png", "3.png"}`,
    `"assets/puzzles/med"` → `{"1.png"}`, `"assets/puzzles/hard"` →
    `{"1.png"}`, plus at least one non-`.png` entry in one tier, e.g. a stray
    `.DS_Store` or `.txt` file, to verify the suffix filter excludes it) so
    the test is self-contained and doesn't depend on what's actually on disk.
  - Test 1: `PuzzleCatalog.list()` returns one flat array combining entries
    from all three mocked tiers (e.g. 5 total paths for the 3/1/1 mock
    above), each path equal to `"assets/puzzles/<tier>/<filename>"`, with the
    non-`.png` mock entry excluded.
  - Test 2 (memoization): call `PuzzleCatalog.list()` twice (or more) within
    the same test run; assert `love.filesystem.getDirectoryItems` (the spy)
    was invoked only as many times as there are tiers (3) in total across
    *all* calls to `PuzzleCatalog.list()` combined — i.e. the second and
    later calls to `.list()` must not trigger additional
    `getDirectoryItems` calls. Because the memoization cache is module-level
    (persists for the process, i.e. across this whole test run once
    `require("game/puzzle_catalog")` has been loaded once), be careful that
    an earlier test in this run (or Task G's tests in `test_jigsaw.lua`, if
    the whole suite runs in one process per `lua/headless/runner.lua`'s
    discovery loop) may have already triggered and cached the *real* scan
    before this test's mock is installed — install the
    `love.filesystem.getDirectoryItems` spy *before* the first call to
    `PuzzleCatalog.list()` in this test file, and if module-level memoization
    means a prior test file already forced a real scan, either accept that
    this test can only observe "no additional real scans happen after the
    first `.list()` call within this test," or (if that ordering risk is
    real) restructure the assertion to check call-count stability across two
    consecutive calls within this test rather than asserting an absolute
    total call count of exactly 3. Prefer whichever framing is robust to test
    execution order without needing to change `puzzle_catalog.lua` itself.
  - Follow this file's/this suite's existing `print("PASS: ...")` convention
    per assertion block (see any existing test file in `tests/` for the exact
    style).
