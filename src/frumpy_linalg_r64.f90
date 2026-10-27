!> Float64 outer, matmul and solve; backend calls preserve C-order results.
module frumpy_linalg_r64
  use iso_fortran_env, only: int32, int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use frumpy_linalg_backend, only: dgemm, dgesv
  use frumpy_broadcast, only: broadcast_plan, broadcast_plan_from_metadata
  use frumpy_access_r64, only: validate_source => validate_r64
  use frumpy_products_r64, only: outer_r64, dot_r64
  use frumpy_ndarray_r64, only: ndarray_r64, owned_descriptor_r64
  use frumpy_strides, only: is_c_contiguous, is_f_contiguous
  use frumpy_shape, only: element_count
  use frumpy_statuses, only: frumpy_status, set_status, FRUMPY_STATUS_OK, &
    FRUMPY_STATUS_INVALID_SHAPE, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
    FRUMPY_STATUS_ALLOCATION_FAILED, &
    FRUMPY_STATUS_OVERFLOW, FRUMPY_STATUS_SINGULAR_MATRIX
  implicit none
  private
  public :: matmul_r64, solve_r64, outer_r64, dot_r64

contains

  !> NumPy vector promotion and broadcasting of leading matrix-stack dimensions.
  function matmul_r64(lhs, rhs, status) result(array)
    type(ndarray_r64), intent(in) :: lhs, rhs
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r64) :: array
    type(frumpy_status) :: local_status
    type(broadcast_plan) :: plan
    integer(int64), allocatable :: shape(:), index0(:)
    real(real64), allocatable :: a(:, :), b(:, :), c(:, :)
    integer(int64) :: m, n, k, rhs_k, row_stride, column_stride, left_k_stride, right_k_stride
    integer(int64) :: row0, column0, inner0, batch1, left_base, right_base, output_base, count
    logical :: both_c, both_f
    integer(int32) :: left_batch_rank, right_batch_rank, output_rank, dim1, alloc_stat

    call validate_source(lhs, local_status)
    if (local_status%is_ok()) call validate_source(rhs, local_status)
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    call set_status(local_status, FRUMPY_STATUS_INVALID_SHAPE, "matmul requires rank >= 1")
    if (lhs%rank < 1 .or. rhs%rank < 1) then
      if (present(status)) status = local_status
      return
    end if
    m = 1_int64
    row_stride = 0_int64
    k = lhs%shape(lhs%rank)
    left_k_stride = lhs%strides(lhs%rank)
    if (lhs%rank > 1) then
      m = lhs%shape(lhs%rank - 1)
      row_stride = lhs%strides(lhs%rank - 1)
    end if
    n = 1_int64
    column_stride = 0_int64
    rhs_k = rhs%shape(1)
    right_k_stride = rhs%strides(1)
    if (rhs%rank > 1) then
      n = rhs%shape(rhs%rank)
      column_stride = rhs%strides(rhs%rank)
      rhs_k = rhs%shape(rhs%rank - 1)
      right_k_stride = rhs%strides(rhs%rank - 1)
    end if
    if (k /= rhs_k) then
      call set_status(local_status, FRUMPY_STATUS_INVALID_SHAPE, "matmul core dimensions differ")
      if (present(status)) status = local_status
      return
    end if
    if (.not. backend_shape_fits(m, n, k)) then
      call set_status(local_status, FRUMPY_STATUS_OVERFLOW, "matmul backend dimensions overflow")
      if (present(status)) status = local_status
      return
    end if
    left_batch_rank = max(0_int32, lhs%rank - 2_int32)
    right_batch_rank = max(0_int32, rhs%rank - 2_int32)
    plan = broadcast_plan_from_metadata(lhs%shape(:left_batch_rank), &
      lhs%strides(:left_batch_rank), rhs%shape(:right_batch_rank), &
      rhs%strides(:right_batch_rank), local_status)
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    output_rank = plan%rank
    if (lhs%rank > 1) output_rank = output_rank + 1_int32
    if (rhs%rank > 1) output_rank = output_rank + 1_int32
    allocate(shape(output_rank), index0(plan%rank), stat=alloc_stat)
    if (alloc_stat /= 0) then
      call set_status(local_status, FRUMPY_STATUS_ALLOCATION_FAILED, &
        "matmul metadata allocation failed")
      if (present(status)) status = local_status
      return
    end if
    shape(:plan%rank) = plan%shape
    dim1 = plan%rank
    if (lhs%rank > 1) then
      dim1 = dim1 + 1_int32
      shape(dim1) = m
    end if
    if (rhs%rank > 1) shape(output_rank) = n
    count = element_count(shape, local_status)
    if (local_status%is_ok()) then
      if (count > shiftr(huge(1_int64), 3)) &
        call set_status(local_status, FRUMPY_STATUS_OVERFLOW, "matmul output byte count overflows")
    end if
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    array = owned_descriptor_r64(shape, status=local_status)
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    if (count == 0_int64 .or. k == 0_int64) then
      array%data = 0.0_real64
      if (present(status)) call set_status(status, FRUMPY_STATUS_OK)
      return
    end if
    both_c = .false.
    both_f = .false.
    if (lhs%rank == 2_int32 .and. rhs%rank == 2_int32) then
      both_c = is_c_contiguous(lhs%shape, lhs%strides) .and. &
        is_c_contiguous(rhs%shape, rhs%strides)
      both_f = is_f_contiguous(lhs%shape, lhs%strides) .and. &
        is_f_contiguous(rhs%shape, rhs%strides)
    end if
    if (both_c .or. both_f) then
      if (.not. all(ieee_is_finite(lhs%data(lhs%offset:lhs%offset + m*k - 1_int64))) &
          .or. .not. all(ieee_is_finite(rhs%data(rhs%offset:rhs%offset + k*n - 1_int64)))) then
        call array%release()
        call set_status(local_status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
          "matmul currently requires finite input values")
        if (present(status)) status = local_status
        return
      end if
      if (both_c) then
        ! C^T = B^T A^T writes C-order output using the backend's NN kernel.
        call dgemm('N', 'N', int(n, int32), int(m, int32), int(k, int32), &
          1.0_real64, rhs%data(rhs%offset:), int(n, int32), &
          lhs%data(lhs%offset:), int(k, int32), 0.0_real64, array%data, int(n, int32))
      else
        ! Retain NN for F inputs: TT direct output severely regresses reference BLAS.
        allocate(c(m, n), stat=alloc_stat)
        if (alloc_stat /= 0) then
          call array%release()
          call set_status(local_status, FRUMPY_STATUS_ALLOCATION_FAILED, &
            "matmul output workspace allocation failed")
          if (present(status)) status = local_status
          return
        end if
        call dgemm('N', 'N', int(m, int32), int(n, int32), int(k, int32), &
          1.0_real64, lhs%data(lhs%offset:), int(m, int32), &
          rhs%data(rhs%offset:), int(k, int32), 0.0_real64, c, int(m, int32))
        call copy_matmul_output(c, array%data)
      end if
      if (present(status)) call set_status(status, FRUMPY_STATUS_OK)
      return
    end if
    allocate(a(m, k), b(k, n), c(m, n), stat=alloc_stat)
    if (alloc_stat /= 0) then
      call array%release()
      call set_status(local_status, FRUMPY_STATUS_ALLOCATION_FAILED, &
        "matmul workspace allocation failed")
      if (present(status)) status = local_status
      return
    end if
    index0 = 0_int64
    do batch1 = 1_int64, plan%size()
      left_base = lhs%offset + sum(index0 * plan%lhs_strides)
      right_base = rhs%offset + sum(index0 * plan%rhs_strides)
      do inner0 = 0_int64, k - 1_int64
        do row0 = 0_int64, m - 1_int64
          a(row0 + 1, inner0 + 1) = &
            lhs%data(left_base + row0 * row_stride + inner0 * left_k_stride)
        end do
        do column0 = 0_int64, n - 1_int64
          b(inner0 + 1, column0 + 1) = &
            rhs%data(right_base + inner0 * right_k_stride + column0 * column_stride)
        end do
      end do
      if (.not. all(ieee_is_finite(a)) .or. .not. all(ieee_is_finite(b))) then
        call array%release()
        call set_status(local_status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
          "matmul currently requires finite input values")
        if (present(status)) status = local_status
        return
      end if
      output_base = (batch1 - 1_int64) * m * n
      call dgemm('N', 'N', int(m, int32), int(n, int32), int(k, int32), &
        1.0_real64, a, int(m, int32), b, int(k, int32), 0.0_real64, c, int(m, int32))
      call copy_matmul_output(c, array%data(output_base + 1_int64:output_base + m*n))
      do dim1 = plan%rank, 1_int32, -1_int32
        index0(dim1) = index0(dim1) + 1_int64
        if (index0(dim1) < plan%shape(dim1)) exit
        index0(dim1) = 0_int64
      end do
    end do
    if (present(status)) call set_status(status, FRUMPY_STATUS_OK)
  end function matmul_r64

  subroutine copy_matmul_output(matrix, output)
    real(real64), intent(in) :: matrix(:, :)
    real(real64), intent(out) :: output(:)
    integer(int64) :: row1, column1, width

    width = size(matrix, 2, kind=int64)
    do row1 = 1_int64, size(matrix, 1, kind=int64)
      do column1 = 1_int64, width
        output((row1 - 1_int64) * width + column1) = matrix(row1, column1)
      end do
    end do
  end subroutine copy_matmul_output

  !> Broadcast stacks of A X = B; only a rank-one B denotes vector right-hand sides.
  function solve_r64(lhs, rhs, status) result(array)
    type(ndarray_r64), intent(in) :: lhs, rhs
    type(frumpy_status), intent(out), optional :: status
    type(ndarray_r64) :: array
    type(frumpy_status) :: local_status
    type(broadcast_plan) :: plan
    real(real64), allocatable :: a(:, :), b(:, :)
    integer(int32), allocatable :: pivots(:)
    integer(int64), allocatable :: shape(:), index0(:)
    integer(int64) :: n, nrhs, row0, column0, rhs_column_stride, count
    integer(int64) :: batch1, left_base, right_base, output_base
    integer(int32) :: alloc_stat, info, left_rank, right_rank, rhs_row, rank, dim1

    call validate_source(lhs, local_status)
    if (local_status%is_ok()) call validate_source(rhs, local_status)
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    call set_status(local_status, FRUMPY_STATUS_INVALID_SHAPE, &
      "solve requires square matrix cores A and vector or matrix cores B")
    if (lhs%rank < 2 .or. rhs%rank < 1) then
      if (present(status)) status = local_status
      return
    end if
    left_rank = lhs%rank - 2_int32
    right_rank = max(0_int32, rhs%rank - 2_int32)
    rhs_row = max(1_int32, rhs%rank - 1_int32)
    n = lhs%shape(lhs%rank)
    if (lhs%shape(lhs%rank - 1) /= n .or. rhs%shape(rhs_row) /= n) then
      if (present(status)) status = local_status
      return
    end if
    nrhs = 1_int64
    rhs_column_stride = 0_int64
    if (rhs%rank > 1) then
      nrhs = rhs%shape(rhs%rank)
      rhs_column_stride = rhs%strides(rhs%rank)
    end if
    if (.not. backend_shape_fits(n, max(1_int64, nrhs), n)) then
      call set_status(local_status, FRUMPY_STATUS_OVERFLOW, "solve backend dimensions overflow")
      if (present(status)) status = local_status
      return
    end if
    plan = broadcast_plan_from_metadata(lhs%shape(:left_rank), lhs%strides(:left_rank), &
      rhs%shape(:right_rank), rhs%strides(:right_rank), local_status)
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    rank = plan%rank + 1_int32
    if (rhs%rank > 1) rank = rank + 1_int32
    allocate(shape(rank), index0(plan%rank), stat=alloc_stat)
    if (alloc_stat /= 0) then
      call set_status(local_status, FRUMPY_STATUS_ALLOCATION_FAILED, "solve metadata allocation")
      if (present(status)) status = local_status
      return
    end if
    shape(:plan%rank) = plan%shape
    shape(plan%rank + 1) = n
    if (rhs%rank > 1) shape(rank) = nrhs
    count = element_count(shape, local_status)
    if (local_status%is_ok()) then
      if (count > shiftr(huge(1_int64), 3)) &
        call set_status(local_status, FRUMPY_STATUS_OVERFLOW, "solve result bytes overflow")
    end if
    if (local_status%is_failure()) then
      if (present(status)) status = local_status
      return
    end if
    array = owned_descriptor_r64(shape, status=local_status)
    if (present(status)) status = local_status
    if (local_status%is_failure()) return
    if (n == 0_int64 .or. plan%size() == 0_int64) return
    allocate(a(n, n), b(n, max(1_int64, nrhs)), pivots(n), stat=alloc_stat)
    if (alloc_stat /= 0) then
      call array%release()
      call set_status(local_status, FRUMPY_STATUS_ALLOCATION_FAILED, &
        "solve workspace allocation failed")
      if (present(status)) status = local_status
      return
    end if
    index0 = 0_int64
    do batch1 = 1_int64, plan%size()
      left_base = lhs%offset + sum(index0 * plan%lhs_strides)
      right_base = rhs%offset + sum(index0 * plan%rhs_strides)
      b = 0.0_real64
      do column0 = 0_int64, n - 1_int64
        do row0 = 0_int64, n - 1_int64
          a(row0 + 1, column0 + 1) = lhs%data(left_base + &
            row0 * lhs%strides(lhs%rank - 1) + column0 * lhs%strides(lhs%rank))
        end do
      end do
      do column0 = 0_int64, nrhs - 1_int64
        do row0 = 0_int64, n - 1_int64
          b(row0 + 1, column0 + 1) = &
            rhs%data(right_base + row0 * rhs%strides(rhs_row) + column0 * rhs_column_stride)
        end do
      end do
      if (.not. all(ieee_is_finite(a)) .or. .not. all(ieee_is_finite(b))) then
        call set_status(local_status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
          "solve currently requires finite input values")
      else
        ! Some backends return early for NRHS=0; a dummy zero column forces factorization.
        call dgesv(int(n, int32), int(max(1_int64, nrhs), int32), a, int(n, int32), pivots, &
          b, int(n, int32), info)
        if (info > 0_int32) then
          call set_status(local_status, FRUMPY_STATUS_SINGULAR_MATRIX, "solve matrix is singular")
        else if (info < 0_int32) then
          call set_status(local_status, FRUMPY_STATUS_UNSUPPORTED_BEHAVIOR, &
            "LAPACK rejected solve arguments")
        end if
      end if
      if (local_status%is_failure()) then
        call array%release()
        if (present(status)) status = local_status
        return
      end if
      output_base = (batch1 - 1_int64) * (n * nrhs)
      do row0 = 0_int64, n - 1_int64
        do column0 = 0_int64, nrhs - 1_int64
          array%data(output_base + row0 * nrhs + column0 + 1_int64) = b(row0 + 1, column0 + 1)
        end do
      end do
      do dim1 = plan%rank, 1_int32, -1_int32
        index0(dim1) = index0(dim1) + 1_int64
        if (index0(dim1) < plan%shape(dim1)) exit
        index0(dim1) = 0_int64
      end do
    end do
  end function solve_r64

  logical function backend_shape_fits(m, n, k)
    integer(int64), intent(in) :: m, n, k
    integer(int64), parameter :: MAX_ELEMENTS = shiftr(huge(1_int64), 3)

    backend_shape_fits = .false.
    if (max(m, n, k) > int(huge(1_int32), int64)) return
    if (m > MAX_ELEMENTS / max(1_int64, k)) return
    if (k > MAX_ELEMENTS / max(1_int64, n)) return
    if (m > MAX_ELEMENTS / max(1_int64, n)) return
    backend_shape_fits = .true.
  end function backend_shape_fits

end module frumpy_linalg_r64
