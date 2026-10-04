#!/usr/bin/env python3
"""Reject unknown keys in helm-unittest suites.

helm-unittest decodes an assertion's parameters with mapstructure.Decode and no
ErrorUnused, so a key it does not recognise is dropped without a word. A typo in
`decodeBase64` therefore turns a guard into an assertion that cannot fail, and
`--strict` does not help: it only applies Go's strict YAML unmarshalling to the
suite and test level, never inside an assertion.

This script closes that gap for the keys `--strict` cannot see. The tables below
are the assertion types and validator fields of helm-unittest PLUGIN_VERSION;
bumping the plugin means regenerating them from pkg/unittest/assertion.go and
pkg/unittest/validators/ at the new tag.

Nothing else can enforce that, so the workflow passes the version it installs as
--plugin-version and this script refuses to run when it does not match
PLUGIN_VERSION. A bump then fails on the line that says what to regenerate,
instead of leaving a guard that silently describes the previous plugin: a type or
parameter added upstream would be rejected as unknown, and one renamed upstream
would keep being accepted under its old spelling.

Usage: check_unittest_keys.py [--plugin-version <v>] <chart-dir> [<chart-dir> ...]
"""

import argparse
import sys
from pathlib import Path

import yaml

# The helm-unittest tag the tables below were generated from. Keep it equal to
# HELM_UNITTEST_VERSION in .github/workflows/helm-ci.yaml, and regenerate the
# tables in the same commit that moves either one.
PLUGIN_VERSION = "1.1.2"

# Assertion.UnmarshalYAML -> parseBasicFields / parseDocumentSelector: the keys
# read next to the assertion type itself.
ASSERTION_KEYS = {"documentindex", "documentselector", "not", "template"}

# assertTypeMapping in pkg/unittest/assertion.go, mapped to the fields of the
# validator struct it names. mapstructure matches field names case-insensitively,
# so every key here is lowercased and compared lowercased.
_CONTAINS_DOCUMENT = {"kind", "apiversion", "name", "namespace", "any"}
_CONTAINS = {"path", "content", "count", "any"}
_PATH_VALUE = {"path", "value"}
_EQUAL = {"path", "value", "decodebase64"}
_EQUAL_RAW = {"value"}
_EXISTS = {"path"}
_FAILED_TEMPLATE = {"errormessage", "errorpattern"}
_HAS_DOCUMENTS = {"count", "filteraware"}
_IS_KIND = {"of"}
_IS_NULL_OR_EMPTY = {"path"}
_IS_SUBSET = {"path", "content"}
_IS_TYPE = {"path", "type"}
_LENGTH_EQUAL = {"paths", "path", "count"}
_MATCH_REGEX = {"path", "pattern", "decodebase64"}
_MATCH_REGEX_RAW = {"pattern"}
_MATCH_SNAPSHOT = {"path", "matchregex", "notmatchregex"}
_MATCH_SNAPSHOT_RAW = set()

ASSERT_TYPES = {
    "matchSnapshot": _MATCH_SNAPSHOT,
    "matchSnapshotRaw": _MATCH_SNAPSHOT_RAW,
    "equal": _EQUAL,
    "notEqual": _EQUAL,
    "greaterOrEqual": _PATH_VALUE,
    "notGreaterOrEqual": _PATH_VALUE,
    "lessOrEqual": _PATH_VALUE,
    "notLessOrEqual": _PATH_VALUE,
    "equalRaw": _EQUAL_RAW,
    "notEqualRaw": _EQUAL_RAW,
    "exists": _EXISTS,
    "notExists": _EXISTS,
    "matchRegex": _MATCH_REGEX,
    "notMatchRegex": _MATCH_REGEX,
    "matchRegexRaw": _MATCH_REGEX_RAW,
    "notMatchRegexRaw": _MATCH_REGEX_RAW,
    "contains": _CONTAINS,
    "notContains": _CONTAINS,
    "isKind": _IS_KIND,
    "isAPIVersion": _IS_KIND,
    "hasDocuments": _HAS_DOCUMENTS,
    "isSubset": _IS_SUBSET,
    "isNotSubset": _IS_SUBSET,
    "isNullOrEmpty": _IS_NULL_OR_EMPTY,
    "isNotNullOrEmpty": _IS_NULL_OR_EMPTY,
    "failedTemplate": _FAILED_TEMPLATE,
    "notFailedTemplate": _FAILED_TEMPLATE,
    "containsDocument": _CONTAINS_DOCUMENT,
    "lengthEqual": _LENGTH_EQUAL,
    "notLengthEqual": _LENGTH_EQUAL,
    "isNull": _EXISTS,
    "isNotNull": _EXISTS,
    "isEmpty": _IS_NULL_OR_EMPTY,
    "isNotEmpty": _IS_NULL_OR_EMPTY,
    "isType": _IS_TYPE,
    "isNotType": _IS_TYPE,
}

# Sub-structs reached through a validator field rather than an assertion type.
NESTED_FIELDS = {
    ("matchSnapshot", "matchregex"): {"pattern"},
    ("matchSnapshot", "notmatchregex"): {"pattern"},
}

_ASSERT_TYPES_LOWER = {name.lower(): name for name in ASSERT_TYPES}


def _known(key, allowed):
    return key.lower() in allowed


def _check_params(where, assert_type, params, errors):
    """Check the mapping under an assertion type against its validator fields."""
    if not isinstance(params, dict):
        return
    allowed = ASSERT_TYPES[assert_type]
    for key, value in params.items():
        key = str(key)
        if not _known(key, allowed):
            errors.append(
                f"{where}: `{assert_type}` has no parameter `{key}` "
                f"(known: {', '.join(sorted(allowed)) or 'none'})"
            )
            continue
        nested = NESTED_FIELDS.get((assert_type, key.lower()))
        if nested and isinstance(value, dict):
            for sub in value:
                if not _known(str(sub), nested):
                    errors.append(
                        f"{where}: `{assert_type}.{key}` has no parameter `{sub}` "
                        f"(known: {', '.join(sorted(nested))})"
                    )


def _check_assertion(where, assertion, errors):
    if not isinstance(assertion, dict):
        errors.append(f"{where}: assertion is not a mapping")
        return
    types = []
    for key in assertion:
        key = str(key)
        canonical = _ASSERT_TYPES_LOWER.get(key.lower())
        if canonical is not None:
            types.append((key, canonical))
        elif not _known(key, ASSERTION_KEYS):
            errors.append(
                f"{where}: unknown assertion key `{key}` "
                f"(expected an assertion type or one of "
                f"{', '.join(sorted(ASSERTION_KEYS))})"
            )
    if not types:
        errors.append(f"{where}: no assertion type")
        return
    if len(types) > 1:
        errors.append(
            f"{where}: {len(types)} assertion types in one assertion "
            f"({', '.join(sorted(k for k, _ in types))})"
        )
    for key, canonical in types:
        _check_params(where, canonical, assertion[key], errors)


def check_suite(path, errors):
    try:
        documents = list(yaml.safe_load_all(path.read_text()))
    except yaml.YAMLError as exc:
        errors.append(f"{path}: not valid YAML: {exc}")
        return
    for document in documents:
        if not isinstance(document, dict):
            continue
        tests = document.get("tests")
        if not isinstance(tests, list):
            continue
        for test_index, test in enumerate(tests):
            if not isinstance(test, dict):
                continue
            name = test.get("it", f"test {test_index}")
            asserts = test.get("asserts")
            if not isinstance(asserts, list):
                continue
            for assert_index, assertion in enumerate(asserts):
                where = f"{path}: `{name}` assertion {assert_index + 1}"
                _check_assertion(where, assertion, errors)


def main(argv):
    parser = argparse.ArgumentParser(
        prog=Path(argv[0]).name,
        description="Reject unknown keys in helm-unittest suites.",
    )
    parser.add_argument(
        "--plugin-version",
        help=(
            "the helm-unittest version CI installs; must equal PLUGIN_VERSION "
            f"({PLUGIN_VERSION}), the tag this script's tables come from"
        ),
    )
    parser.add_argument("charts", nargs="+", metavar="chart-dir")
    args = parser.parse_args(argv[1:])

    if args.plugin_version is not None and args.plugin_version != PLUGIN_VERSION:
        print(
            f"::error file=.github/scripts/check_unittest_keys.py::"
            f"helm-unittest is pinned at {args.plugin_version} but this script's "
            f"tables were generated at {PLUGIN_VERSION}. Regenerate ASSERT_TYPES, "
            f"ASSERTION_KEYS and NESTED_FIELDS from pkg/unittest/assertion.go and "
            f"pkg/unittest/validators/ at tag v{args.plugin_version}, then set "
            f"PLUGIN_VERSION to {args.plugin_version}.",
        )
        return 2

    errors = []
    suites = 0
    for chart in args.charts:
        for path in sorted(Path(chart).glob("tests/*_test.yaml")):
            suites += 1
            check_suite(path, errors)
    for error in errors:
        print(f"::error::{error}")
    print(f"Checked {suites} suite(s), {len(errors)} problem(s).")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
