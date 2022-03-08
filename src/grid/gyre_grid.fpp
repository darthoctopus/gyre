! Module   : gyre_grid
! Purpose  : segmented grids
!
! Copyright 2013-2022 Rich Townsend & The GYRE Team
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

module gyre_grid

  ! Uses

  use core_kinds

  use gyre_point

  use ISO_FORTRAN_ENV

  ! No implicit typing

  implicit none

  ! Derived-type definitions

  type :: grid_t
     type(point_t), allocatable :: pt(:)
     integer                    :: n_p
   contains
     private
     procedure, public :: pt_i
     procedure, public :: pt_o
     procedure, public :: pt_x
     procedure, public :: s_i
     procedure, public :: s_o
     procedure, public :: s_x
     procedure, public :: x_i
     procedure, public :: x_o
     procedure, public :: p_s_i
     procedure, public :: p_s_o
  end type grid_t

  ! Interfaces

  interface grid_t
     module procedure grid_t_x_
     module procedure grid_t_nest_
     module procedure grid_t_refine_
  end interface grid_t

  ! Access specifiers

  private

  public :: grid_t

  ! Procedures

contains

  function grid_t_x_ (x) result (gr)

    real(WP), intent(in) :: x(:)
    type(grid_t)         :: gr

    integer :: n_p
    integer :: s
    integer :: p

    ! Construct a grid_t from the input abscissae x (with segment
    ! boundaries delineated by double points)

    n_p = SIZE(x)

    if (n_p > 0) then

       $ASSERT_DEBUG(ALL(x(2:) >= x(:n_p-1)),Non-monotonic data)
       
       allocate(gr%pt(n_p))

       s = 1

       gr%pt(1)%x = x(1)
       gr%pt(1)%s = s

       do p = 2, n_p

          if (x(p) == x(p-1)) then
             s = s + 1
          endif
          
          gr%pt(p)%x = x(p)
          gr%pt(p)%s = s

       end do

    end if

    gr%n_p = n_p

    ! Check for degenerate segments

    check_loop : do s = 1, gr%pt(n_p)%s
       $ASSERT(COUNT(gr%pt%s == s) >= 2,Degenerate segment)
    end do check_loop

    ! Finish

    return

  end function grid_t_x_

  !****

  function grid_t_nest_ (gr_base, x_i, x_o) result (gr)

    type(grid_t), intent(in) :: gr_base
    real(WP), intent(in)     :: x_i
    real(WP), intent(in)     :: x_o
    type(grid_t)             :: gr

    real(WP)                   :: x_i_
    real(WP)                   :: x_o_
    type(point_t)              :: pt_i
    type(point_t)              :: pt_o
    type(point_t), allocatable :: pt_int(:)

    ! Construct a grid_t as a nesting of gr_base, with limits
    ! (x_i,x_o)

    ! First, restrict the limits to the range of gr_base

    x_i_ = MAX(x_i, gr_base%x_i())
    x_o_ = MIN(x_o, gr_base%x_o())

    ! Set up inner and outer points

    pt_i = gr_base%pt_x(x_i_)
    pt_o = gr_base%pt_x(x_o_, back=.TRUE.)

    ! Select internal points from gr_base to include (excluding
    ! boundary points)

    pt_int = PACK(gr_base%pt, MASK=(gr_base%pt%x > x_i_ .AND. gr_base%pt%x < x_o_))

    ! Create the grid_t

    gr%pt = [pt_i,pt_int,pt_o]
    gr%n_p = SIZE(gr%pt)

    ! Finish

    return

  end function grid_t_nest_

  !****

  function grid_t_refine_ (gr_base, refine) result (gr)

    type(grid_t), intent(in) :: gr_base
    logical, intent(in)      :: refine(:)
    type(grid_t)             :: gr

    integer  :: n_p_base
    integer  :: n_p
    integer  :: p
    integer  :: j

    $CHECK_BOUNDS(SIZE(refine),gr_base%n_p-1)

    ! Construct a grid_t by refining gr_base, with additional points
    ! added to the middle of subintervals where refine == .TRUE.

    n_p_base = gr_base%n_p
    n_p = n_p_base + COUNT(refine)

    allocate(gr%pt(n_p))

    p = 1

    sub_loop : do j = 1, n_p_base-1

       associate (pt_a => gr_base%pt(j), &
                  pt_b => gr_base%pt(j+1))

         gr%pt(p) = pt_a

         p = p + 1

         if (refine(j)) then

            $ASSERT(pt_a%s == pt_b%s,Attempt to add points at segment boundary)

            gr%pt(p)%s = pt_a%s
            gr%pt(p)%x = 0.5_WP*(pt_a%x + pt_b%x)

            p = p + 1

         endif

       end associate

    end do sub_loop

    gr%pt(p) = gr_base%pt(n_p_base)

    gr%n_p = n_p

    ! Finish

    return

  end function grid_t_refine_

  !****

  function pt_i (this)

    class(grid_t), intent(in) :: this
    type(point_t)             :: pt_i

    ! Return the innermost point of the grid

    pt_i = this%pt(1)

    ! Finish

    return

  end function pt_i

  !****

  function pt_o (this)

    class(grid_t), intent(in) :: this
    type(point_t)             :: pt_o

    ! Return the outermost point of the grid

    pt_o = this%pt(this%n_p)

    ! Finish

    return

  end function pt_o

  !****

  function pt_x (this, x, back) result (pt)

    class(grid_t), intent(in)     :: this
    real(WP), intent(in)          :: x
    logical, intent(in), optional :: back
    type(point_t)                 :: pt

    ! Return a point containing the abcissa x. If back is present and
    ! .TRUE., the segment search is done outside-in; otherwise, it is
    ! inside-out (see s_x)

    pt%s = this%s_x(x, back)
    pt%x = x

    ! Finish

    return

  end function pt_x

  !****

  function s_i (this)

    class(grid_t), intent(in) :: this
    integer                   :: s_i

    type(point_t) :: pt_i

    ! Return the innermost segment of the grid

    pt_i = this%pt_i()

    s_i = pt_i%s

    ! Finish

    return

  end function s_i

  !****

  function s_o (this)

    class(grid_t), intent(in) :: this
    integer                   :: s_o

    type(point_t) :: pt_o

    ! Return the outermost segment of the grid

    pt_o = this%pt_o()

    s_o = pt_o%s

    ! Finish

    return

  end function s_o

  !****

  function s_x (this, x, back) result (s)

    class(grid_t), intent(in)     :: this
    real(WP), intent(in)          :: x
    logical, intent(in), optional :: back
    integer                       :: s

    logical :: back_
    integer :: s_a
    integer :: s_b
    integer :: ds
    integer :: p_i
    integer :: p_o

    if (PRESENT(back)) then
       back_ = back
    else
       back_ = .FALSE.
    endif

    ! Locate the segment which brackets the abcissa x. If back is
    ! present and .TRUE., the search is done outside-in; otherwise, it
    ! is inside-out. If x is not inside the grid, then return a
    ! segment index just above/below the maximum/minimum segment of
    ! the grid

    if (back_) then
       s_a = this%pt(this%n_p)%s
       s_b = this%pt(1)%s
       ds = -1
    else
       s_a = this%pt(1)%s
       s_b = this%pt(this%n_p)%s
       ds = 1
    endif

    seg_loop : do s = s_a, s_b, ds

       p_i = this%p_s_i(s)
       p_o = this%p_s_o(s)
         
       if (x >= this%pt(p_i)%x .AND. x <= this%pt(p_o)%x) exit seg_loop
       
    end do seg_loop

    ! Finish

    return

  end function s_x

  !****

  function x_i (this)

    class(grid_t), intent(in) :: this
    real(WP)                  :: x_i

    type(point_t) :: pt_i

    ! Return the innermost abscissa of the grid

    pt_i = this%pt_i()

    x_i = pt_i%x

    ! Finish

    return

  end function x_i

  !****

  function x_o (this)

    class(grid_t), intent(in) :: this
    real(WP)                  :: x_o

    type(point_t) :: pt_o

    ! Return the outermost abscissa of the grid

    pt_o = this%pt_o()

    x_o = pt_o%x

    ! Finish

    return

  end function x_o

  !****

  function p_s_i (this, s) result (p_i)

    class(grid_t), intent(in) :: this
    integer, intent(in)       :: s
    integer                   :: p_i

    $ASSERT_DEBUG(s >= this%s_i(),Invalid segment)
    $ASSERT_DEBUG(s <= this%s_o(),Invalid segment)

    ! Return the index of the innermost point in segment s

    do p_i = 1, this%n_p
       if (this%pt(p_i)%s == s) exit
    end do

    ! Finish

    return

 end function p_s_i

  !****

  function p_s_o (this, s) result (p_o)

    class(grid_t), intent(in) :: this
    integer, intent(in)       :: s
    integer                   :: p_o

    $ASSERT_DEBUG(s >= this%s_i(),Invalid segment)
    $ASSERT_DEBUG(s <= this%s_o(),Invalid segment)

    ! Return the index of the outermost point in segment s

    do p_o = this%n_p, 1, -1
       if (this%pt(p_o)%s == s) exit
    end do

    ! Finish

    return

 end function p_s_o

end module gyre_grid
