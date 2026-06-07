"""NumPy reference fixtures for the WP05 r64 constructor subset."""

import pytest

np = pytest.importorskip("numpy")


def constructor_reference_cases():
    return [
        (
            "zeros_c",
            np.zeros((2, 3), dtype=np.float64, order="C"),
            (2, 3),
            [0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        ),
        (
            "ones_c",
            np.ones((2, 2), dtype=np.float64, order="C"),
            (2, 2),
            [1.0, 1.0, 1.0, 1.0],
        ),
        (
            "full_f",
            np.full((2, 3), 2.5, dtype=np.float64, order="F"),
            (2, 3),
            [2.5, 2.5, 2.5, 2.5, 2.5, 2.5],
        ),
        (
            "arange",
            np.arange(0.0, 5.0, 1.0, dtype=np.float64),
            (5,),
            [0.0, 1.0, 2.0, 3.0, 4.0],
        ),
        (
            "linspace",
            np.linspace(0.0, 1.0, 5, endpoint=True, dtype=np.float64),
            (5,),
            [0.0, 0.25, 0.5, 0.75, 1.0],
        ),
        (
            "linspace_no_endpoint",
            np.linspace(0.0, 1.0, 4, endpoint=False, dtype=np.float64),
            (4,),
            [0.0, 0.25, 0.5, 0.75],
        ),
    ]


@pytest.mark.parametrize(
    ("name", "array", "shape", "flat_values"),
    constructor_reference_cases(),
)
def test_constructor_reference_cases(name, array, shape, flat_values):
    assert array.dtype == np.float64, name
    assert array.shape == shape, name
    np.testing.assert_allclose(array.ravel(order="C"), flat_values)


def test_order_reference_cases():
    values = np.array([1.0, 2.0, 3.0, 4.0, 5.0, 6.0], dtype=np.float64)
    c_matrix = values.reshape((2, 3), order="C")
    f_matrix = np.array(c_matrix, order="F", copy=True)

    np.testing.assert_allclose(c_matrix.ravel(order="C"), values)
    np.testing.assert_allclose(
        f_matrix.ravel(order="K"),
        np.array([1.0, 4.0, 2.0, 5.0, 3.0, 6.0], dtype=np.float64),
    )
