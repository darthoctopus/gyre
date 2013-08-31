! Module   : gyre_coeffs_mpi
! Purpose  : MPI support for gyre_coeffs
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

module gyre_coeffs_mpi

  ! Uses

  use core_parallel

  use gyre_coeffs
  use gyre_evol_coeffs
  use gyre_poly_coeffs
  use gyre_hom_coeffs

  use ISO_FORTRAN_ENV

  ! No implicit typing

  implicit none

  ! Interfaces

  $if($MPI)
  interface bcast_alloc
     module procedure bcast_alloc_cf
  end interface bcast_alloc
  $endif

  ! Access specifiers

  private

  $if($MPI)
  public :: bcast_alloc
  $endif

  ! Procedures

contains

  $if($MPI)

  subroutine bcast_alloc_cf (cf, root_rank)

    class(coeffs_t), allocatable, intent(inout) :: cf
    integer, intent(in)                         :: root_rank

    integer, parameter :: EVOL_TYPE = 1
    integer, parameter :: POLY_TYPE = 2
    integer, parameter :: HOM_TYPE = 3

    logical :: alloc
    integer :: type

    ! Deallocate the coeffs on non-root processors

    if(MPI_RANK /= root_rank .AND. ALLOCATED(cf)) then
       deallocate(cf)
    endif

    ! Check if the coeffs is allocated on the root processor

    if(MPI_RANK == root_rank) alloc = ALLOCATED(cf)
    call bcast(alloc, root_rank)

    if(alloc) then

       ! Broadcast the dynamic type

       if(MPI_RANK == root_rank) then

          select type (cf)
          type is (evol_coeffs_t)
             type = EVOL_TYPE
          type is (poly_coeffs_t)
             type = POLY_TYPE
          type is (hom_coeffs_t)
             type = HOM_TYPE
          class default
             $ABORT(Unsupported type)
          end select
          
       end if

       call bcast(type, root_rank)

       ! Allocate the coeffs

       if(MPI_RANK /= root_rank) then
          select case (type)
          case (EVOL_TYPE)
             allocate(evol_coeffs_t::cf)
          case (POLY_TYPE)
             allocate(poly_coeffs_t::cf)
          case(HOM_TYPE)
             allocate(hom_coeffs_t::cf)
          case default
             $ABORT(Unsupported type)
          end select
       endif

       ! Broadcast the coeffs

       select type (cf)
       type is (evol_coeffs_t)
          call bcast(cf, root_rank)
       type is (poly_coeffs_t)
          call bcast(cf, root_rank)
       type is (hom_coeffs_t)
          call bcast(cf, root_rank)
       class default
          $ABORT(Unsupported type)
       end select
          
    endif

    ! Finish

  end subroutine bcast_alloc_cf

  $endif

end module gyre_coeffs_mpi