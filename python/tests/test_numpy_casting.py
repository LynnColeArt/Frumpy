import numpy as np


OBSERVED_NUMPY_VERSION = "2.4.6"

DTYPES = {
    "bool": np.bool_,
    "i32": np.int32,
    "i64": np.int64,
    "r32": np.float32,
    "r64": np.float64,
}

EXPECTED_CAN_CAST = {
    "no": {
        "bool": {"bool"},
        "i32": {"i32"},
        "i64": {"i64"},
        "r32": {"r32"},
        "r64": {"r64"},
    },
    "equiv": {
        "bool": {"bool"},
        "i32": {"i32"},
        "i64": {"i64"},
        "r32": {"r32"},
        "r64": {"r64"},
    },
    "safe": {
        "bool": {"bool", "i32", "i64", "r32", "r64"},
        "i32": {"i32", "i64", "r64"},
        "i64": {"i64", "r64"},
        "r32": {"r32", "r64"},
        "r64": {"r64"},
    },
    "same_kind": {
        "bool": {"bool", "i32", "i64", "r32", "r64"},
        "i32": {"i32", "i64", "r32", "r64"},
        "i64": {"i32", "i64", "r32", "r64"},
        "r32": {"r32", "r64"},
        "r64": {"r32", "r64"},
    },
    "unsafe": {
        "bool": {"bool", "i32", "i64", "r32", "r64"},
        "i32": {"bool", "i32", "i64", "r32", "r64"},
        "i64": {"bool", "i32", "i64", "r32", "r64"},
        "r32": {"bool", "i32", "i64", "r32", "r64"},
        "r64": {"bool", "i32", "i64", "r32", "r64"},
    },
}


def test_observed_numpy_version_is_pinned():
    assert np.__version__ == OBSERVED_NUMPY_VERSION


def test_expected_can_cast_matrix_matches_numpy_oracle():
    for casting, source_map in EXPECTED_CAN_CAST.items():
        for source_name, expected_targets in source_map.items():
            actual_targets = {
                target_name
                for target_name, target_dtype in DTYPES.items()
                if np.can_cast(
                    DTYPES[source_name],
                    target_dtype,
                    casting=casting,
                )
            }

            assert actual_targets == expected_targets


def test_numpy_unsafe_casts_can_be_lossy():
    values = np.array([0.1], dtype=np.float64)

    assert np.can_cast(np.float64, np.float32, casting="unsafe")
    assert values.astype(np.float32, casting="unsafe").astype(np.float64)[0] != (
        values[0]
    )
