"""NumPy reference fixtures for the WP10 searching subset."""

import pytest

np = pytest.importorskip("numpy")


def test_numpy_searchsorted_reference_cases():
    source = np.array([1.0, 3.0, 3.0, 7.0], dtype=np.float64)
    values = np.array([0.0, 1.0, 2.0, 3.0, 4.0, 7.0, 8.0], dtype=np.float64)

    left = np.searchsorted(source, values)
    right = np.searchsorted(source, values, side="right")

    np.testing.assert_array_equal(left, [0, 0, 1, 1, 3, 3, 4])
    np.testing.assert_array_equal(right, [0, 1, 1, 3, 3, 4, 4])


def test_numpy_searchsorted_empty_source_and_values_shape_reference_case():
    source = np.array([], dtype=np.float64)
    values = np.array([[0.0, 2.0], [4.0, 6.0]], dtype=np.float64)

    result = np.searchsorted(source, values)

    assert result.shape == values.shape
    np.testing.assert_array_equal(result, np.zeros_like(values, dtype=np.intp))
