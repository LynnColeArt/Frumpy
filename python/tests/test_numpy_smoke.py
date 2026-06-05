"""NumPy oracle smoke tests for Fenum compatibility work."""

from __future__ import annotations

import unittest

try:
    import numpy as np
except ModuleNotFoundError:  # pragma: no cover - exercised only without NumPy
    np = None


@unittest.skipIf(np is None, "NumPy is not installed")
class NumPyOracleSmokeTest(unittest.TestCase):
    def test_scalar_broadcast_preserves_shape(self) -> None:
        values = np.arange(3.0)

        actual = values + 2.0

        np.testing.assert_allclose(actual, np.array([2.0, 3.0, 4.0]))
        self.assertEqual(actual.shape, (3,))

    def test_default_two_dimensional_storage_is_c_contiguous(self) -> None:
        values = np.zeros((2, 3), dtype=np.float64)

        self.assertTrue(values.flags.c_contiguous)
        self.assertFalse(values.flags.f_contiguous)


if __name__ == "__main__":
    unittest.main()
