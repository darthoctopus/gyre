! Module   : gyre_eigfunc
! Purpose  : eigenfunction data
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

module gyre_eigfunc

  ! Uses

  use core_kinds
  use core_parallel
  use core_hgroup

  use gyre_bvp
  use gyre_mech_coeffs
  use gyre_oscpar

  use ISO_FORTRAN_ENV

  ! No implicit typing

  implicit none

  ! Derived-type definitions

  type :: eigfunc_t
     type(oscpar_t)           :: op
     real(WP), allocatable    :: x(:)
     complex(WP), allocatable :: xi_r(:)
     complex(WP), allocatable :: xi_h(:)
     complex(WP), allocatable :: phip(:)
     complex(WP), allocatable :: dphip_dx(:)
     complex(WP), allocatable :: delS(:)
     complex(WP), allocatable :: delL(:)
     complex(WP)              :: omega
     integer                  :: n
   contains
     private
     procedure, public :: init
     procedure, public :: classify
     procedure, public :: dK_dx
     procedure, public :: K
     procedure, public :: E
  end type eigfunc_t

  ! Interfaces

  $if($MPI)

  interface bcast
     module procedure bcast_ef
  end interface bcast

  $endif

  ! Access specifiers

  private

  public :: eigfunc_t
  $if($MPI)
  public :: bcast
  $endif

  ! Procedures

contains

  subroutine init (this, op, omega, x, xi_r, xi_h, phip, dphip_dx, delS, delL)

    class(eigfunc_t), intent(out)    :: this
    type(oscpar_t), intent(in)       :: op
    complex(WP), intent(in)          :: omega
    real(WP), intent(in)             :: x(:)
    complex(WP), intent(in)          :: xi_r(:)
    complex(WP), intent(in)          :: xi_h(:)
    complex(WP), intent(in)          :: phip(:)
    complex(WP), intent(in)          :: dphip_dx(:)
    complex(WP), intent(in)          :: delS(:)
    complex(WP), intent(in)          :: delL(:)

    $CHECK_BOUNDS(SIZE(xi_r),SIZE(x))
    $CHECK_BOUNDS(SIZE(xi_h),SIZE(x))
    $CHECK_BOUNDS(SIZE(phip),SIZE(x))
    $CHECK_BOUNDS(SIZE(dphip_dx),SIZE(x))
    $CHECK_BOUNDS(SIZE(delS),SIZE(x))
    $CHECK_BOUNDS(SIZE(delL),SIZE(x))

    ! Initialize the eigfunc

    this%op = op

    this%x = x

    this%xi_r = xi_r
    this%xi_h = xi_h
    this%phip = phip
    this%dphip_dx = dphip_dx
    this%delS = delS
    this%delL = delL

    this%omega = omega

    this%n = SIZE(this%x)

    ! Finish

    return

  end subroutine init

!****

  $if($MPI)

  subroutine bcast_ef (this, root_rank)

    class(eigfunc_t), intent(inout) :: this
    integer, intent(in)             :: root_rank

    ! Broadcast the eigfunc

    call bcast(this%op, root_rank)

    call bcast_alloc(this%x, root_rank)

    call bcast_alloc(this%xi_r, root_rank)
    call bcast_alloc(this%xi_h, root_rank)
    call bcast_alloc(this%phip, root_rank)
    call bcast_alloc(this%dphip_dx, root_rank)
    call bcast_alloc(this%delS, root_rank)
    call bcast_alloc(this%delL, root_rank)

    call bcast(this%n, root_rank)

  end subroutine bcast_ef

  $endif

!****

  subroutine classify (this, n_p, n_g)

    class(eigfunc_t), intent(in) :: this
    integer, intent(out)         :: n_p
    integer, intent(out)         :: n_g

    real(WP) :: xi_r(this%n)
    real(WP) :: xi_h(this%n)
    logical  :: inner_ext
    integer  :: i
    real(WP) :: y_2_cross

    ! Classify the eigenfunction using the Cowling-Scuflaire scheme

    xi_r = REAL(this%xi_r)
    xi_h = REAL(this%xi_h)

    n_p = 0
    n_g = 0
 
    inner_ext = ABS(xi_r(1)) > ABS(this%xi_r(2))

    x_loop : do i = 2,this%n-1

       ! If the innermost extremum in y_1 hasn't yet been reached,
       ! skip

       if(.NOT. inner_ext) then
          inner_ext = ABS(xi_r(i)) > ABS(xi_r(i-1)) .AND. ABS(xi_r(i)) > ABS(xi_r(i+1))
          cycle x_loop
       endif

       ! Look for a node in xi_r

       if(xi_r(i) >= 0._WP .AND. xi_r(i+1) < 0._WP) then

          y_2_cross = xi_h(i) - xi_r(i)*(xi_h(i+1) - xi_h(i))/(xi_r(i+1) - xi_r(i))

          if(y_2_cross >= 0._WP) then
             n_p = n_p + 1
          else
             n_g = n_g + 1
          endif

       elseif(xi_r(i) <= 0._WP .AND. xi_r(i+1) > 0._WP) then

         y_2_cross = xi_h(i) - xi_r(i)*(xi_h(i+1) - xi_h(i))/(xi_r(i+1) - xi_r(i))

          if(y_2_cross <= 0._WP) then
             n_p = n_p + 1
          else
             n_g = n_g + 1
          endif

       endif

    end do x_loop

    ! Finish

    return

  end subroutine classify

!*****

  function dK_dx (this, mc)

    class(eigfunc_t), intent(in)     :: this
    class(mech_coeffs_t), intent(in) :: mc
    real(WP)                         :: dK_dx(this%n)
    
    integer     :: i

    ! Calculate the differential kinetic energy in units of GM^2/R

    do i = 1,this%n
       associate(U => mc%U(this%x(i)), c_1 => mc%c_1(this%x(i)))
         dK_dx(i) = (ABS(this%xi_r(i))**2 + this%op%l*(this%op%l+1)*ABS(this%xi_h(i))**2)*U*this%x(i)**2/c_1
       end associate
    end do

    ! Finish

    return

  end function dK_dx

!*****

  function K (this, mc)

    class(eigfunc_t), intent(in)     :: this
    class(mech_coeffs_t), intent(in) :: mc
    real(WP)                         :: K
    
    ! Calculate the kinetic energy

    K = integrate(this%x, this%dK_dx(mc))

    ! Finish

    return

  end function K

!*****

  function E (this, mc)

    class(eigfunc_t), intent(in)     :: this
    class(mech_coeffs_t), intent(in) :: mc
    real(WP)                         :: E

    real(WP) :: A2
    real(WP) :: K

    ! Calculate the normalized mode inertia, using the expression
    ! given by Christensen-Dalsgaard (2011, arXiv:1106.5946, his
    ! eqn. 2.32)

    A2 = ABS(this%xi_r(this%n))**2 + this%op%l*(this%op%l+1)*ABS(this%xi_h(this%n))**2

    K = this%K(mc)

    if(A2 == 0._WP) then
       $WARN(Surface amplitude is zero; not normalizing inertia)
       E = K
    else
       E = K/A2
    endif

    ! Finish

    return

  end function E

!****

  function integrate (x, y) result (int_y)

    real(WP), intent(in) :: x(:)
    real(WP), intent(in) :: y(:)
    real(WP)             :: int_y

    integer :: n

    $CHECK_BOUNDS(SIZE(y),SIZE(x))

    ! Integrate y(x) using trapezoidal quadrature

    n = SIZE(x)

    int_y = SUM(0.5_WP*(y(2:) + y(:n-1))*(x(2:) - x(:n-1)))

    ! Finish

    return

  end function integrate

end module gyre_eigfunc
