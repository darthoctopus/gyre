! Module   : gyre_rad_jacobian
! Purpose  : radial adiabatic Jacobian evaluation
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

module gyre_rad_jacobian

  ! Uses

  use core_kinds

  use gyre_jacobian
  use gyre_base_coeffs
  use gyre_oscpar

  use ISO_FORTRAN_ENV

  ! No implicit typing

  implicit none

  ! Derived-type definitions

  type, extends(jacobian_t) :: rad_jacobian_t
     private
     class(base_coeffs_t), pointer :: bc => null()
     type(oscpar_t), pointer       :: op => null()
   contains
     private
     procedure, public :: init
     procedure, public :: eval
     procedure, public :: eval_logx
  end type rad_jacobian_t

  ! Access specifiers

  private

  public :: rad_jacobian_t

  ! Procedures

contains

  subroutine init (this, bc, op)

    class(rad_jacobian_t), intent(out)       :: this
    class(base_coeffs_t), intent(in), target :: bc
    type(oscpar_t), intent(in), target       :: op

    ! Initialize the ad_jacobian

    this%bc => bc
    this%op => op

    this%n_e = 2

    ! Finish

    return

  end subroutine init

!****

  subroutine eval (this, omega, x, A)

    class(rad_jacobian_t), intent(in) :: this
    complex(WP), intent(in)           :: omega
    real(WP), intent(in)              :: x
    complex(WP), intent(out)          :: A(:,:)
    
    ! Evaluate the Jacobian matrix

    call this%eval_logx(omega, x, A)

    A = A/x

    ! Finish

    return

  end subroutine eval

!****

  subroutine eval_logx (this, omega, x, A)

    class(rad_jacobian_t), intent(in) :: this
    complex(WP), intent(in)           :: omega
    real(WP), intent(in)              :: x
    complex(WP), intent(out)          :: A(:,:)
    
    $CHECK_BOUNDS(SIZE(A, 1),this%n_e)
    $CHECK_BOUNDS(SIZE(A, 2),this%n_e)

    ! Evaluate the log(x)-space Jacobian matrix

    associate(V_g => this%bc%V(x)/this%bc%Gamma_1(x), U => this%bc%U(x), &
              As => this%bc%As(x), c_1 => this%bc%c_1(x))

      A(1,1) = V_g - 1._WP
      A(1,2) = -V_g
      
      A(2,1) = c_1*omega**2 + U - As
      A(2,2) = As - U + 3._WP

    end associate

    ! Finish

    return

  end subroutine eval_logx

end module gyre_rad_jacobian