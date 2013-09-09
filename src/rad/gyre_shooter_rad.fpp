! Module   : gyre_shooter_rad
! Purpose  : radial adiabatic multiple shooting
!
! Copyright 2013 Rich Townsend
!
! This file is part of GYRE. GYRE is free software: you can
! redistribute it and/or modify it under the terms of the GNU General
! Public License as published by the Free Software Foundation, version 3.
!
! GYRE is distributed in the hope that it will be useful, but WITHOUT
! ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
! or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
! License for more details.
!
! You should have received a copy of the GNU General Public License
! along with this program.  If not, see <http://www.gnu.org/licenses/>.

$include 'core.inc'

module gyre_shooter_rad

  ! Uses

  use core_kinds

  use gyre_coeffs
  use gyre_oscpar
  use gyre_numpar
  use gyre_jacobian
  use gyre_sysmtx
  use gyre_ext_arith
  use gyre_ivp, ivp_abscissa => abscissa

  use ISO_FORTRAN_ENV

  ! No implicit typing

  implicit none

  ! Derived-type definitions

  type :: shooter_rad_t
     private
     class(coeffs_t), pointer   :: cf => null()
     class(jacobian_t), pointer :: jc => null()
     type(oscpar_t), pointer    :: op => null()
     type(numpar_t), pointer    :: np => null()
     integer, public            :: n_e
   contains
     private
     procedure, public :: init
     procedure, public :: shoot
     procedure, public :: recon => recon_sh
     procedure, public :: abscissa
  end type shooter_rad_t

  ! Access specifiers

  private

  public :: shooter_rad_t

  ! Procedures

contains

  subroutine init (this, cf, jc, op, np)

    class(shooter_rad_t), intent(out)     :: this
    class(coeffs_t), intent(in), target   :: cf
    class(jacobian_t), intent(in), target :: jc
    type(oscpar_t), intent(in), target    :: op
    type(numpar_t), intent(in), target    :: np

    ! Initialize the shooter_rad

    this%cf => cf
    this%jc => jc
    this%op => op
    this%np => np

    this%n_e = this%jc%n_e

    ! Finish

    return

  end subroutine init

!****

  subroutine shoot (this, omega, x, sm)

    class(shooter_rad_t), intent(in) :: this
    complex(WP), intent(in)          :: omega
    real(WP), intent(in)             :: x(:)
    class(sysmtx_t), intent(inout)   :: sm

    integer             :: k
    complex(WP)         :: E_l(this%n_e,this%n_e)
    complex(WP)         :: E_r(this%n_e,this%n_e)
    type(ext_complex_t) :: S

    ! Set the sysmtx equation blocks by solving IVPs across the
    ! intervals x(k) -> x(k+1)

    !$OMP PARALLEL DO PRIVATE (E_l, E_r, S) SCHEDULE (DYNAMIC)
    block_loop : do k = 1,SIZE(x)-1
       call solve(this%np%ivp_solver_type, this%jc, omega, x(k), x(k+1), E_l, E_r, S, use_real=.TRUE.)
       call sm%set_block(k, E_l, E_r, S)
    end do block_loop

    ! Finish

  end subroutine shoot

!****

  subroutine recon_sh (this, omega, x_sh, y_sh, x, y)

    class(shooter_rad_t), intent(in) :: this
    complex(WP), intent(in)          :: omega
    real(WP), intent(in)             :: x_sh(:)
    complex(WP), intent(in)          :: y_sh(:,:)
    real(WP), intent(in)             :: x(:)
    complex(WP), intent(out)         :: y(:,:)

    integer     :: n_sh
    integer     :: n
    integer     :: k
    logical     :: mask(SIZE(x))
    integer     :: n_in
    integer     :: i
    integer     :: i_in(SIZE(x))
    real(WP)    :: x_in(SIZE(x))
    complex(WP) :: y_in(this%n_e,SIZE(x))

    $CHECK_BOUNDS(SIZE(y_sh, 1),this%n_e)
    $CHECK_BOUNDS(SIZE(y_sh, 2),SIZE(x_sh))

    $CHECK_BOUNDS(SIZE(y, 1),this%n_e)
    $CHECK_BOUNDS(SIZE(y, 2),SIZE(x))

    ! Reconstruct the eigenfunctions on the supplied grid

    n_sh = SIZE(x_sh)
    n = SIZE(x)

    !$OMP PARALLEL DO PRIVATE (mask, n_in, i_in, x_in, y_in) SCHEDULE (DYNAMIC)
    recon_loop : do k = 1,n_sh-1

       ! Select those points which fall in the current interval

       if(k == 1) then
          mask = x < x_sh(k+1)
       elseif(k == n_sh-1) then
          mask = x >= x_sh(k)
       else
          mask = x >= x_sh(k) .AND. x < x_sh(k+1)
       endif

       n_in = COUNT(mask)

       if(n_in > 0) then

          ! Reconstruct in the interval

          i_in(:n_in) = PACK([(i,i=1,n)], MASK=mask)

          x_in(:n_in) = x(i_in(:n_in))

          call recon(this%np%ivp_solver_type, this%jc, omega, x_sh(k), x_sh(k+1), y_sh(:,k), y_sh(:,k+1), &
               x_in(:n_in), y_in(:,:n_in), use_real=.TRUE.)

          y(:,i_in(:n_in)) = y_in(:,:n_in)

       endif

    end do recon_loop
    
    ! Finish

    return

  end subroutine recon_sh

!****

  function abscissa (this, x_sh) result (x)

    class(shooter_rad_t), intent(in) :: this
    real(WP), intent(in)             :: x_sh(:)
    real(WP), allocatable            :: x(:)

    integer :: k
    integer :: n_cell(SIZE(x_sh)-1)
    integer :: i

    ! Determine the abscissa used for shooting on the grid x_sh

    !$OMP PARALLEL DO SCHEDULE (DYNAMIC)
    count_loop : do k = 1,SIZE(x_sh)-1
       n_cell(k) = SIZE(ivp_abscissa(this%np%ivp_solver_type, x_sh(k), x_sh(k+1)))
    end do count_loop

    allocate(x(SUM(n_cell)))

    i = 1

    cell_loop : do k = 1,SIZE(x_sh)-1
       x(i:i+n_cell(k)-1) = ivp_abscissa(this%np%ivp_solver_type, x_sh(k), x_sh(k+1))
       i = i + n_cell(k)
    end do cell_loop

    $CHECK_BOUNDS(i,SIZE(x)+1)

    ! Finish

    return

  end function abscissa

end module gyre_shooter_rad