"""NumPy reference fixtures for WP07 r64 reductions."""

import pytest

np = pytest.importorskip("numpy")


def test_numpy_axis_reduction_reference_cases():
    source = np.array([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]], dtype=np.float64)

    np.testing.assert_allclose(np.sum(source, axis=0).ravel(order="C"), [5, 7, 9])
    np.testing.assert_allclose(np.sum(source, axis=1).ravel(order="C"), [6, 15])
    np.testing.assert_allclose(np.prod(source, axis=1).ravel(order="C"), [6, 120])
    np.testing.assert_allclose(np.min(source, axis=0).ravel(order="C"), [1, 2, 3])
    np.testing.assert_allclose(np.max(source, axis=1).ravel(order="C"), [3, 6])
    np.testing.assert_allclose(
        np.mean(source, axis=0).ravel(order="C"),
        [2.5, 3.5, 4.5],
    )


def test_numpy_keepdims_and_all_axis_reference_cases():
    source = np.array([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]], dtype=np.float64)

    kept_axis = np.sum(source, axis=1, keepdims=True)
    assert kept_axis.shape == (2, 1)
    np.testing.assert_allclose(kept_axis.ravel(order="C"), [6, 15])

    kept_all = np.sum(source, keepdims=True)
    assert kept_all.shape == (1, 1)
    np.testing.assert_allclose(kept_all.ravel(order="C"), [21])

    mean_all = np.mean(source)
    assert mean_all.shape == ()
    np.testing.assert_allclose(mean_all, 3.5)


def test_numpy_empty_reduction_reference_cases():
    empty_matrix = np.empty((0, 3), dtype=np.float64)

    np.testing.assert_allclose(np.sum(empty_matrix, axis=0), [0, 0, 0])
    np.testing.assert_allclose(np.prod(empty_matrix, axis=0), [1, 1, 1])

    empty_mean = np.mean(empty_matrix, axis=0)
    assert empty_mean.shape == (3,)
    assert np.isnan(empty_mean).all()

    with pytest.raises(ValueError, match="zero-size array"):
        np.min(empty_matrix, axis=0)

    empty_result = np.max(empty_matrix, axis=1)
    assert empty_result.shape == (0,)


def test_numpy_first_vertical_slice_reference_case():
    a = np.zeros((2, 3), dtype=np.float64)
    b = np.full((3,), 2.0, dtype=np.float64)
    c = a + b
    d = np.reshape(c, (3, 2))
    e = np.sum(d, axis=1)

    np.testing.assert_allclose(e.ravel(order="C"), [4, 4, 4])
