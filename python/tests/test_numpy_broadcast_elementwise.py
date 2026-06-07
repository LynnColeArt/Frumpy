"""NumPy reference fixtures for WP06 broadcasting and r64 elementwise kernels."""

import pytest

np = pytest.importorskip("numpy")


def test_binary_broadcast_reference_cases():
    lhs = np.array([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]], dtype=np.float64)
    rhs = np.array([10.0, 20.0, 30.0], dtype=np.float64)

    np.testing.assert_allclose(
        (lhs + rhs).ravel(order="C"),
        [11, 22, 33, 14, 25, 36],
    )
    np.testing.assert_allclose(
        (lhs - rhs).ravel(order="C"),
        [-9, -18, -27, -6, -15, -24],
    )
    np.testing.assert_allclose(
        (lhs * rhs).ravel(order="C"),
        [10, 40, 90, 40, 100, 180],
    )
    np.testing.assert_allclose(
        (lhs / rhs).ravel(order="C"),
        [0.1, 0.1, 0.1, 0.4, 0.25, 0.2],
    )


def test_scalar_and_column_broadcast_reference_cases():
    vector = np.array([1.0, 2.0, 3.0], dtype=np.float64)
    scalar = np.array(2.0, dtype=np.float64)
    np.testing.assert_allclose((scalar * vector).ravel(order="C"), [2, 4, 6])

    lhs = np.array(
        [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]],
        dtype=np.float64,
        order="F",
    )
    rhs = np.array([[10.0], [20.0]], dtype=np.float64)
    np.testing.assert_allclose(
        (lhs + rhs).ravel(order="C"),
        [11, 12, 13, 24, 25, 26],
    )

    empty = np.empty((0, 3), dtype=np.float64)
    row = np.array([[10.0, 20.0, 30.0]], dtype=np.float64)
    assert (empty + row).shape == (0, 3)


def test_unary_reference_cases():
    source = np.array([-1.0, 0.0, 4.0], dtype=np.float64)
    np.testing.assert_allclose(np.abs(source), [1, 0, 4])
    np.testing.assert_allclose(np.sqrt(np.abs(source)), [1, 0, 2])

    log_source = np.array([1.0, np.e], dtype=np.float64)
    np.testing.assert_allclose(np.log(log_source), [0, 1])

    exp_source = np.array([0.0, 1.0], dtype=np.float64)
    np.testing.assert_allclose(np.exp(exp_source), [1, np.e])

    trig_source = np.array([0.0, np.pi / 2.0, np.pi], dtype=np.float64)
    np.testing.assert_allclose(np.sin(trig_source), [0, 1, 0], atol=1e-12)
    np.testing.assert_allclose(np.cos(trig_source), [1, 0, -1], atol=1e-12)
