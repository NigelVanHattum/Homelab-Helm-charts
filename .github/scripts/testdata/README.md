# check_unittest_keys.py fixtures

The self-check of the `suite-keys` job in `.github/workflows/helm-ci.yaml`.

- `good/` — one suite whose every construct the script must accept. The script
  must exit 0 over it.
- `bad/<case>/` — one suite per case the script must reject, one defect each so a
  passing case cannot mask a broken one. The script must exit 1 over each
  directory on its own.

These are deliberately **not** under `charts/`. `check_unittest_keys.py` takes
chart directories and globs `tests/*_test.yaml`, and the `coverage` job requires
every `charts/*` directory to ship suites, so a fixture chart here would break
both. They are never rendered, so the `templates/` they name need not exist.

Adding a case: create `bad/<case>/tests/<case>_test.yaml` with exactly one
defect, and add the valid spelling of the same construct to `good/`. The
workflow picks both up from the glob; no workflow edit is needed.
