# Fork releases

This fork of [roflmuffin/CounterStrikeSharp](https://github.com/roflmuffin/CounterStrikeSharp) builds and publishes its own GitHub releases. `main` stays aligned with upstream. Releases are cut from `bleeding-edge`, `bleeding-edge-sigs`, and `hotfix/<name>` branches. The first two start at upstream `505e466` (`main` on 24 Sep 2026).

That commit includes `a55cb8b` ("feat: implement KHook (#1418)"), which bumps `libraries/metamod-source`. These builds require **Metamod 2.x build 1467 or newer, with KHook**. They are not the `v1.0.374` line, which targets Metamod dev build 1411.

`bleeding-edge-sigs` matches `bleeding-edge` until signature or gamedata changes land on that branch.

## Tags

The patch is one higher than the latest plain upstream tag (`v1.0.374` becomes `1.0.375`). The trailing number increments for each later release of that channel on the same patch. After upstream publishes `v1.0.375`, the next fork tag on each channel is `v1.0.376-<channel>.1`.

- `bleeding-edge` → `v1.0.375-bleeding-edge.1`, then `v1.0.375-bleeding-edge.2`, …
- `bleeding-edge-sigs` → `v1.0.375-bleeding-edgesigs.1`, then `v1.0.375-bleeding-edgesigs.2`, …
- `hotfix/<name>` → `v1.0.375-hotfix.1`, then `v1.0.375-hotfix.2`, …

Tags contain a hyphen, so GitHub marks them as prereleases. They still start with `v`, which is what starts the publish workflow.

## Cut a release

From `bleeding-edge` or `bleeding-edge-sigs`:

```bash
./create-release.sh --dry-run
./create-release.sh
```

A hotfix hangs off the current `bleeding-edge` tip and stays on that commit. Cut a branch named `hotfix/<name>`, commit the workaround there, and release from that branch. When `bleeding-edge` later gets its own fix, leave this branch where it is. Cut a new `hotfix/<name>` from the new tip if a workaround is still required.

```bash
git switch -c hotfix/<name> bleeding-edge
./create-release.sh --dry-run --channel hotfix
./create-release.sh --channel hotfix
```

`--dry-run` prints the next tag, writes the changelog commit, and creates the tag locally. It does not push. A real run pushes that branch and the tag. The tag push builds Linux, Windows, and the managed API, then attaches these assets to a GitHub release:

- `counterstrikesharp-linux-<semver>.zip`
- `counterstrikesharp-windows-<semver>.zip`
- `counterstrikesharp-with-runtime-linux-<semver>.zip`
- `counterstrikesharp-with-runtime-windows-<semver>.zip`

NuGet publishing is omitted. The package id is still upstream `CounterStrikeSharp.API`. Discord notifications run only when the `DISCORD_WEBHOOK` secret is set.

One-time repository settings: enable Actions, and set Settings → Actions → General → Workflow permissions to read and write so the release can be created.
