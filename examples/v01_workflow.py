"""Run with the installed package; NumPy verifies the declared native results."""
import numpy as np
import frumpy as fp

parent = fp.asarray([[1., 2.], [3., 4.]])
view = parent.T
parent.close()
assert not view.flags.owndata
reference = np.array([[1., 2.], [3., 4.]]).T
integers = fp.asarray([10, 20], dtype=fp.int32)
totals = (view + integers).sum(axis=1)
selected = view[view > 2.]
product = view @ fp.asarray(np.eye(2))
system, rhs = fp.asarray([[4., 1.], [1., 3.]]), fp.asarray([1., 2.])
solution = fp.linalg.solve(system, rhs)
np.testing.assert_array_equal(totals.numpy(), (reference + np.array([10, 20])).sum(axis=1))
np.testing.assert_array_equal(selected.numpy(), reference[reference > 2])
np.testing.assert_array_equal(product.numpy(), reference)
np.testing.assert_allclose(solution.numpy(), np.linalg.solve(system.numpy(), rhs.numpy()))
print("row sums:", totals.tolist())
print("selected:", selected.tolist())
print("solution:", solution.tolist())
