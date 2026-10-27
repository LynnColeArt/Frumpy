!> Conventional LP64 Fortran BLAS/LAPACK interfaces: int32 dimensions and real32/real64 values.
module frumpy_linalg_backend
  use iso_fortran_env, only: int32, real32, real64
  implicit none
  private
  public :: dgemm, dgesv, sgemm, sgesv

  interface
    subroutine dgemm(transa, transb, m, n, k, alpha, a, lda, b, ldb, beta, c, ldc)
      import :: int32, real64
      character(len=1), intent(in) :: transa, transb
      integer(int32), intent(in) :: m, n, k, lda, ldb, ldc
      real(real64), intent(in) :: alpha, beta, a(lda, *), b(ldb, *)
      real(real64), intent(inout) :: c(ldc, *)
    end subroutine dgemm

    subroutine dgesv(n, nrhs, a, lda, ipiv, b, ldb, info)
      import :: int32, real64
      integer(int32), intent(in) :: n, nrhs, lda, ldb
      real(real64), intent(inout) :: a(lda, *), b(ldb, *)
      integer(int32), intent(out) :: ipiv(*), info
    end subroutine dgesv
    subroutine sgemm(transa, transb, m, n, k, alpha, a, lda, b, ldb, beta, c, ldc)
      import :: int32, real32
      character(len=1), intent(in) :: transa, transb
      integer(int32), intent(in) :: m, n, k, lda, ldb, ldc
      real(real32), intent(in) :: alpha, beta, a(lda, *), b(ldb, *)
      real(real32), intent(inout) :: c(ldc, *)
    end subroutine sgemm

    subroutine sgesv(n, nrhs, a, lda, ipiv, b, ldb, info)
      import :: int32, real32
      integer(int32), intent(in) :: n, nrhs, lda, ldb
      real(real32), intent(inout) :: a(lda, *), b(ldb, *)
      integer(int32), intent(out) :: ipiv(*), info
    end subroutine sgesv
  end interface
end module frumpy_linalg_backend
