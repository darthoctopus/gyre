! Module   : gyre_c_search
! Purpose  : mode searching (complex)
!
! Copyright 2013-2014 Rich Townsend
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

module gyre_c_search

  ! Uses

  use core_kinds
  use gyre_constants
  use core_order
  use core_parallel

  use gyre_bvp
  use gyre_ext
  use gyre_discfunc
!  use gyre_grid
  use gyre_mode
  use gyre_model
  use gyre_numpar
  use gyre_util

  use ISO_FORTRAN_ENV

  ! No implicit typing

  implicit none

  ! Access specifiers

  private

  public :: prox_search

contains

  subroutine prox_search (bp, np, md_in, process_root)

    class(c_bvp_t), target, intent(inout) :: bp
    type(numpar_t), intent(in)            :: np
    type(mode_t), intent(in)              :: md_in(:)
    interface
       subroutine process_root (omega, n_iter, discrim_ref)
         use core_kinds
         use gyre_ext
         complex(WP), intent(in)   :: omega
         integer, intent(in)       :: n_iter
         type(r_ext_t), intent(in) :: discrim_ref
       end subroutine process_root
    end interface
    
    type(c_discfunc_t)       :: df
    complex(WP), allocatable :: omega_def(:)
    integer                  :: c_beg
    integer                  :: c_end
    integer                  :: c_rate
    integer                  :: i
    type(c_ext_t)            :: omega_a
    type(c_ext_t)            :: omega_b
    integer                  :: n_iter
    integer                  :: n_iter_def
    type(c_ext_t)            :: discrim_a
    type(c_ext_t)            :: discrim_b
    type(c_ext_t)            :: discrim_a_rev
    type(c_ext_t)            :: discrim_b_rev
    complex(WP)              :: omega_root

    ! Set up the discriminant function

    df = c_discfunc_t(bp)

    ! Initialize the frequency deflation array

    allocate(omega_def(0))

    ! Process each initial mode to find a proximate mode

    if (check_log_level('INFO')) then

       write(OUTPUT_UNIT, 100) 'Root Solving'
100    format(A)

       write(OUTPUT_UNIT, 110) 'l', 'n_pg', 'n_p', 'n_g', 'Re(omega)', 'Im(omega)', 'chi', 'n_iter', 'n'
110    format(4(2X,A8),3(2X,A24),2X,A6,2X,A7)
       
    endif

    call SYSTEM_CLOCK(c_beg, c_rate)

    mode_loop : do i = 1, SIZE(md_in)

       ! Set up initial guesses

       omega_a = md_in(i)%omega*c_ext_t(CMPLX(1._WP,  SQRT(EPSILON(0._WP)), KIND=WP))
       omega_b = md_in(i)%omega*c_ext_t(CMPLX(1._WP, -SQRT(EPSILON(0._WP)), KIND=WP))

       discrim_a = df%eval(omega_a)
       discrim_b = df%eval(omega_b)

       ! If necessary, do a preliminary root find using the deflated
       ! discriminant

       if (np%deflate_roots) then

          n_iter_def = np%n_iter_max

          df%omega_def = omega_def

          call df%narrow(omega_a, omega_b, r_ext_t(0._WP), n_iter=n_iter_def)

          $ASSERT(n_iter_def <= np%n_iter_max,Too many deflation iterations)

          deallocate(df%omega_def)

          ! If necessary, reset omega_a and omega_b so they are not
          ! coincident

          if(omega_b == omega_a) then
             omega_b = omega_a*(1._WP + EPSILON(0._WP)*(omega_a/ABS(omega_a)))
          endif

          call df%expand(omega_a, omega_b, r_ext_t(0._WP), discrim_a_rev, discrim_b_rev)

       else

          discrim_a_rev = discrim_a
          discrim_b_rev = discrim_b

          n_iter_def = 0

       endif

       ! Find the discriminant root

       n_iter = np%n_iter_max - n_iter_def

       omega_root = cmplx(df%root(omega_a, omega_b, r_ext_t(0._WP), &
                                  f_cx_a=discrim_a_rev, f_cx_b=discrim_b_rev, n_iter=n_iter))

       n_iter = n_iter + n_iter_def

       $ASSERT(n_iter <= np%n_iter_max,Too many iterations)

       ! Process it

       call process_root(omega_root, n_iter, max(abs(discrim_a), abs(discrim_b)))

       ! Store the frequency in the deflation array

       omega_def = [omega_def,omega_root]

    end do mode_loop

    call SYSTEM_CLOCK(c_end)

    if (check_log_level('INFO')) then
       write(OUTPUT_UNIT, 130) 'Time elapsed :', REAL(c_end-c_beg, WP)/c_rate, 's'
130    format(2X,A,1X,F10.3,1X,A)
    endif

    ! Finish

    return

  end subroutine prox_search

end module gyre_c_search
