import numpy as np


OBSERVED_NUMPY_VERSION = "2.4.6"

DTYPES = {
    "bool": np.bool_,
    "i32": np.int32,
    "i64": np.int64,
    "r32": np.float32,
    "r64": np.float64,
}

EXPECTED_PROMOTIONS = {
    ("bool", "bool"): "bool",
    ("bool", "i32"): "i32",
    ("bool", "i64"): "i64",
    ("bool", "r32"): "r32",
    ("bool", "r64"): "r64",
    ("i32", "i32"): "i32",
    ("i32", "i64"): "i64",
    ("i32", "r32"): "r64",
    ("i32", "r64"): "r64",
    ("i64", "i64"): "i64",
    ("i64", "r32"): "r64",
    ("i64", "r64"): "r64",
    ("r32", "r32"): "r32",
    ("r32", "r64"): "r64",
    ("r64", "r64"): "r64",
}

NUMPY_TO_FRUMPY_NAME = {
    "bool": "bool",
    "int32": "i32",
    "int64": "i64",
    "float32": "r32",
    "float64": "r64",
}


def promote_name(lhs_name, rhs_name):
    numpy_result = np.promote_types(DTYPES[lhs_name], DTYPES[rhs_name])
    return NUMPY_TO_FRUMPY_NAME[numpy_result.name]


def test_observed_numpy_version_is_pinned():
    assert np.__version__ == OBSERVED_NUMPY_VERSION


def test_expected_promotions_match_numpy_oracle():
    for (lhs_name, rhs_name), expected_name in EXPECTED_PROMOTIONS.items():
        assert promote_name(lhs_name, rhs_name) == expected_name
        assert promote_name(rhs_name, lhs_name) == expected_name


def test_numpy_scalar_like_dtype_promotions_match_table_policy():
    scalar_like_cases = [
        ("i32", "r32", "r64"),
        ("r32", "bool", "r32"),
        ("i64", "r32", "r64"),
    ]

    for array_name, scalar_name, expected_name in scalar_like_cases:
        array = np.array([1], dtype=DTYPES[array_name])
        scalar = DTYPES[scalar_name](1)

        assert NUMPY_TO_FRUMPY_NAME[np.result_type(array, scalar).name] == (
            expected_name
        )
        assert NUMPY_TO_FRUMPY_NAME[(array + scalar).dtype.name] == expected_name
