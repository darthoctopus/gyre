! Program  : gyre_tide_util
! Purpose  : tide-related utility functions
!
! Copyright 2018 Rich Townsend
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

module gyre_tide_util

  ! Uses

  use core_kinds

  use gyre_constants
  use gyre_util

  use ISO_FORTRAN_ENV

  ! No implicit typing

  implicit none

  ! Access specifiers

  private

  public :: X_lmk
  public :: beta_lm

  ! Procedures

contains

  function X_lmk (ec, l, m, k)

    real(WP), intent(in) :: ec
    integer, intent(in)  :: l
    integer, intent(in)  :: m
    integer, intent(in)  :: k
    real(WP)             :: X_lmk

    integer, parameter :: N = 1024

    integer  :: i
    real(WP) :: ua(N)
    real(WP) :: Ea
    real(WP) :: Ma
    real(WP) :: y(N)

    $ASSERT_DEBUG(ABS(m) <= l,Invalid m)

    ! Evaluate the Hansen coefficient X_lmk, using the transformed
    ! integral expression given in eqn. (22) of Smeyers, Willems & Van
    ! Hoolst (1998, A&A, 335, 622) (this expression avoids having to
    ! solve Kepler's equation)

    ! Set up the integrand

    do i = 1, N

       ua(i) = (i-1)*PI/(N-1)

       Ea = 2._WP*ATAN(SQRT((1._WP-ec)/(1._WP+ec))*TAN(ua(i)/2._WP))

       Ma = Ea - ec*SIN(Ea)

       y(i) = COS(k*Ma - m*ua(i))/(1._WP + ec*COS(ua(i)))**(l+2)

    end do

    ! Do the integral

    X_lmk = integrate(ua, y)*(1._WP - ec**2)**(l+1.5_WP)/PI

    ! Finish

    return

  end function X_lmk

  !****

  function beta_lm (l, m)

    integer, intent(in)  :: l
    integer, intent(in)  :: m
    real(WP)             :: beta_lm

    integer  :: am
    integer  :: j
    real(WP) :: sj

    $ASSERT_DEBUG(ABS(m) <= l,Invalid m)

    ! Evaluate beta_lm = N_lm P_lm(0), where
    ! N_lm = SQRT((2l+1)/4pi*(l-m)!/(l+m)!) is the spherical harmonic
    ! normalization function, and P_lm(x) is the associated Legendre
    ! function including the Condon-Shortley phase term

    am = ABS(m)

    if (MOD(l+am, 2) == 0) then

       ! Evaluate N_l|m| P_l|m|(0)

       beta_lm = (-1)**((l+am)/2)*SQRT((2*l+1)/(4*PI))

       do j = 1, l+am

          sj = SQRT(REAL(j, WP))

          if (j <= l-am) beta_lm = beta_lm*sj
          if (j <= l+am) beta_lm = beta_lm/sj

          if (MOD(j, 2) == 0) then
             if (j <= l-am) beta_lm = beta_lm/j
          else
             if (j <= l+am-1) beta_lm = beta_lm*j
          endif

       end do

       ! Adjust the sign for negative m (we do things this way to
       ! ensure that opposite-m betas have identical magnitude)

       if (m < 0) beta_lm = (-1)**am*beta_lm

    else

       beta_lm = 0._WP

    end if

    ! Finish

    return

  end function beta_lm

end module gyre_tide_util