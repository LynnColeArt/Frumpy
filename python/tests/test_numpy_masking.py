"""NumPy reference fixtures for the WP10 boolean-mask subset."""

import pytest

np = pytest.importorskip("numpy")


def test_numpy_flatnonzero_reference_cases():
    vector = np.array([0, 1, 0, 1], dtype=np.int8)
    matrix = np.array([[1, 0, 1], [0, 1, 0]], dtype=np.int8, order="F")
    scalar_true = np.array(True)
    scalar_false = np.array(False)

    np.testing.assert_array_equal(np.flatnonzero(vector), [1, 3])
    np.testing.assert_array_equal(np.flatnonzero(matrix), [0, 2, 4])
    np.testing.assert_array_equal(np.flatnonzero(scalar_true), [0])
    np.testing.assert_array_equal(np.flatnonzero(scalar_false), [])


def test_numpy_flatnonzero_empty_reference_case():
    empty = np.empty((0, 3), dtype=np.int8)

    result = np.flatnonzero(empty)

    assert result.shape == (0,)
    np.testing.assert_array_equal(result, np.array([], dtype=np.intp))
