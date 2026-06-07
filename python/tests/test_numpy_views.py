"""NumPy reference fixtures for WP08 view behavior."""

import pytest

np = pytest.importorskip("numpy")


def test_numpy_reshape_ravel_and_flatten_reference_cases():
    source = np.array([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]], dtype=np.float64)

    reshaped = np.reshape(source, (3, 2))
    assert np.shares_memory(source, reshaped)
    np.testing.assert_allclose(reshaped.ravel(order="C"), [1, 2, 3, 4, 5, 6])

    raveled = np.ravel(source)
    assert np.shares_memory(source, raveled)

    flattened = source.flatten()
    assert not np.shares_memory(source, flattened)

    transposed = source.T
    noncontiguous_ravel = np.ravel(transposed)
    assert not np.shares_memory(source, noncontiguous_ravel)
    np.testing.assert_allclose(noncontiguous_ravel, [1, 4, 2, 5, 3, 6])


def test_numpy_transpose_swapaxes_squeeze_expand_reference_cases():
    source = np.array([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]], dtype=np.float64)

    transposed = np.transpose(source)
    swapped = np.swapaxes(source, 0, 1)
    assert np.shares_memory(source, transposed)
    assert np.shares_memory(source, swapped)
    np.testing.assert_allclose(transposed.ravel(order="C"), [1, 4, 2, 5, 3, 6])
    np.testing.assert_allclose(swapped.ravel(order="C"), [1, 4, 2, 5, 3, 6])

    shaped = source.reshape((1, 2, 1, 3))
    squeezed = np.squeeze(shaped)
    expanded = np.expand_dims(squeezed, axis=1)
    assert squeezed.shape == (2, 3)
    assert expanded.shape == (2, 1, 3)
    assert np.shares_memory(source, squeezed)
    assert np.shares_memory(source, expanded)


def test_numpy_slice_reference_cases():
    source = np.array([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]], dtype=np.float64)

    row = source[1:2, :]
    assert row.shape == (1, 3)
    assert np.shares_memory(source, row)
    np.testing.assert_allclose(row.ravel(order="C"), [4, 5, 6])

    reversed_columns = source[:, 2::-1]
    assert reversed_columns.shape == (2, 3)
    assert np.shares_memory(source, reversed_columns)
    np.testing.assert_allclose(
        reversed_columns.ravel(order="C"),
        [3, 2, 1, 6, 5, 4],
    )

    empty_columns = source[:, 3:3]
    assert empty_columns.shape == (2, 0)


def test_numpy_first_vertical_slice_uses_reshape_reference_case():
    a = np.zeros((2, 3), dtype=np.float64)
    b = np.full((3,), 2.0, dtype=np.float64)
    c = a + b
    d = np.reshape(c, (3, 2))
    e = np.sum(d, axis=1)

    assert np.shares_memory(c, d)
    np.testing.assert_allclose(e.ravel(order="C"), [4, 4, 4])
