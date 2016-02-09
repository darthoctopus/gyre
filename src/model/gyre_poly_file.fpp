! Module   : gyre_poly_file
! Purpose  : read POLY files
!
! Copyright 2013-2016 Rich Townsend
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

module gyre_poly_file

  ! Uses

  use core_kinds
  use core_hgroup

  use gyre_model
  use gyre_model_par
  use gyre_poly_model
  use gyre_util

  use ISO_FORTRAN_ENV

  ! No implicit typing

  implicit none

  ! Access specifiers

  private

  public :: read_poly_model

  ! Procedures

contains

  subroutine read_poly_model (ml_p, ml)

    type(model_par_t), intent(in)        :: ml_p
    class(model_t), pointer, intent(out) :: ml

    type(hgroup_t)              :: hg
    real(WP)                    :: Gamma_1
    real(WP), allocatable       :: n_poly(:)
    real(WP), allocatable       :: xi(:)
    real(WP), allocatable       :: Theta(:)
    real(WP), allocatable       :: dTheta(:)
    type(poly_model_t), pointer :: pm

    ! Read the POLY-format file

    if (check_log_level('INFO')) then
       write(OUTPUT_UNIT, 100) 'Reading from POLY file', TRIM(ml_p%file)
100    format(A,1X,A)
    endif

    hg = hgroup_t(ml_p%file, OPEN_FILE)

    call read_attr(hg, 'Gamma_1', Gamma_1)
    call read_attr_alloc(hg, 'n_poly', n_poly)

    call read_dset_alloc(hg, 'xi', xi)
    call read_dset_alloc(hg, 'Theta', Theta)
    call read_dset_alloc(hg, 'dTheta', dTheta)

    call hg%final()

    ! Initialize the poly_model_t

    allocate(pm, SOURCE=poly_model_t(xi, Theta, dTheta, n_poly, Gamma_1, ml_p))

    ! Return a pointer

    ml => pm

    ! Finish

    return

  end subroutine read_poly_model

end module gyre_poly_file
