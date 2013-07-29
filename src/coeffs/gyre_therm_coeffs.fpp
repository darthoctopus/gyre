! Module   : gyre_therm_coeffs
! Purpose  : thermal structure coefficients (interface)
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

module gyre_therm_coeffs

  ! Uses

  use core_kinds

  ! No implicit typing

  implicit none

  ! Derived-type definitions

  $define $PROC_DECL $sub
    $local $NAME $1
    procedure(c_1_i), deferred :: ${NAME}_1
    procedure(c_v_i), deferred :: ${NAME}_v
    generic, public            :: ${NAME} => ${NAME}_1, ${NAME}_v
  $endsub

  type, abstract :: therm_coeffs_t
     private
   contains
     private
     $if($GFORTRAN_PR57922)
     procedure, public :: final
     $endif
     $PROC_DECL(c_rad)
     $PROC_DECL(dc_rad)
     $PROC_DECL(c_thm)
     $PROC_DECL(c_dif)
     $PROC_DECL(c_eps_ad)
     $PROC_DECL(c_eps_S)
     $PROC_DECL(nabla)
     $PROC_DECL(kappa_ad)
     $PROC_DECL(kappa_S)
     $PROC_DECL(epsilon_ad)
     $PROC_DECL(epsilon_S)
     $PROC_DECL(tau_thm)
     procedure(enable_cache_i), deferred, public :: enable_cache
     procedure(enable_cache_i), deferred, public :: disable_cache
     procedure(fill_cache_i), deferred, public   :: fill_cache
  end type therm_coeffs_t

  ! Interfaces

  abstract interface

     function c_1_i (this, x) result (c)
       use core_kinds
       import therm_coeffs_t
       class(therm_coeffs_t), intent(in) :: this
       real(WP), intent(in)              :: x
       real(WP)                          :: c
     end function c_1_i

     function c_v_i (this, x) result (c)
       use core_kinds
       import therm_coeffs_t
       class(therm_coeffs_t), intent(in) :: this
       real(WP), intent(in)              :: x(:)
       real(WP)                          :: c(SIZE(x))
     end function c_v_i

     subroutine enable_cache_i (this)
       import therm_coeffs_t
       class(therm_coeffs_t), intent(inout) :: this
     end subroutine enable_cache_i

     subroutine fill_cache_i (this, x)
       use core_kinds
       import therm_coeffs_t
       class(therm_coeffs_t), intent(inout) :: this
       real(WP), intent(in)                 :: x(:)
     end subroutine fill_cache_i

  end interface

 ! Access specifiers

  private

  public :: therm_coeffs_t

contains

  $if($GFORTRAN_PR57922)

  subroutine final (this)

    class(therm_coeffs_t), intent(inout) :: this

    ! Finalize the therm_coeffs

    ! Finish

    return

  end subroutine final

  $endif

end module gyre_therm_coeffs