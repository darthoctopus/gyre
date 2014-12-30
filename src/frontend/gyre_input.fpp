! Program  : gyre_input
! Purpose  : input routines
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

module gyre_input

  ! Uses

  use core_kinds
  use core_order
  use core_parallel
  use core_system

  use gyre_constants
  use gyre_modepar
  use gyre_oscpar
  use gyre_numpar
  use gyre_gridpar
  use gyre_scanpar
  use gyre_outpar

  use ISO_FORTRAN_ENV

  ! No implicit typing

  implicit none

  ! Access specifiers

  private

  public :: init_system
  public :: read_constants
  public :: read_model
  public :: read_modepar
  public :: read_oscpar
  public :: read_numpar
  public :: read_scanpar
  public :: read_shoot_gridpar
  public :: read_recon_gridpar
  public :: read_outpar

contains

  subroutine init_system (filename, gyre_dir)

    character(:), allocatable, intent(out) :: filename
    character(:), allocatable, intent(out) :: gyre_dir

    integer :: status

    ! Get command-line arguments

    $ASSERT(n_arg() == 1,Invalid number of arguments)

    call get_arg(1, filename)

    ! Get environment variables

    call get_env('GYRE_DIR', gyre_dir, status)
    $ASSERT(status == 0,The GYRE_DIR environment variable is not set)

    ! Finish

    return

  end subroutine init_system

!****

  subroutine read_model (unit, x_bc, ml)

    use gyre_model
    use gyre_evol_model
    use gyre_scons_model
    use gyre_poly_model
    use gyre_hom_model
    use gyre_mesa_file
    use gyre_osc_file
    use gyre_losc_file
    use gyre_fgong_file
    use gyre_famdl_file
    use gyre_amdl_file
    $if ($HDF5)
    use gyre_b3_file
    use gyre_gsm_file
    use gyre_poly_file
    $endif

    integer, intent(in)                  :: unit
    real(WP), allocatable, intent(out)   :: x_bc(:)
    class(model_t), pointer, intent(out) :: ml

    integer                 :: n_ml
    character(256)          :: model_type
    character(256)          :: file_format
    character(256)          :: data_format
    character(256)          :: deriv_type
    character(FILENAME_LEN) :: file
    real(WP)                :: Gamma_1
    logical                 :: override_As
    logical                 :: uniform_rot
    real(WP)                :: Omega_rot
    type(evol_model_t)      :: ec
    type(scons_model_t)     :: sc
    type(poly_model_t)      :: pc
    type(hom_model_t)       :: hc

    namelist /model/ model_type, file_format, data_format, deriv_type, &
                     file, Gamma_1, &
                     override_As, uniform_rot, Omega_rot

    ! Count the number of model namelists

    rewind(unit)

    n_ml = 0

    count_loop : do
       read(unit, NML=model, END=100)
       n_ml = n_ml + 1
    end do count_loop

100 continue

    $ASSERT(n_ml == 1,Input file should contain exactly one &model namelist)

    ! Read model parameters

    model_type = ''
    file_format = ''
    data_format = ''
    deriv_type = 'MONO'
    uniform_rot = .FALSE.
    override_As = .FALSE.

    file = ''

    Gamma_1 = 5._WP/3._WP
    Omega_rot = 0._WP

    rewind(unit)
    read(unit, NML=model)

    ! Read/initialize the model

    select case (model_type)
    case ('EVOL')

       select case (file_format)
       case ('MESA')
          if (uniform_rot) then
             call read_mesa_model(file, deriv_type, ec, x=x_bc, uni_Omega_rot=Omega_rot)
          else
             call read_mesa_model(file, deriv_type, ec, x=x_bc)
          endif
       case('B3')
          $if($HDF5)
          call read_b3_model(file, deriv_type, ec, x=x_bc)
          $else
          $ABORT(No HDF5 support, therefore cannot read B3-format files)
          $endif
       case ('GSM')
          $if($HDF5)
          call read_gsm_model(file, deriv_type, ec, x=x_bc)
          $else
          $ABORT(No HDF5 support, therefore cannot read GSM-format files)
          $endif
       case ('OSC')
          call read_osc_model(file, deriv_type, data_format, ec, x=x_bc)
       case ('LOSC')
          call read_losc_model(file, deriv_type, ec, x=x_bc)
       case ('FGONG')
          call read_fgong_model(file, deriv_type, data_format, ec, x=x_bc) 
       case ('FAMDL')
          call read_famdl_model(file, deriv_type, data_format, ec, x=x_bc)
       case ('AMDL')
          call read_amdl_model(file, deriv_type, ec, x=x_bc)
       case default
          $ABORT(Invalid file_format)
       end select

       ec%override_As = override_As

       allocate(ml, SOURCE=ec)

    case ('SCONS')

       select case (file_format)
       case ('MESA')
          call read_mesa_model(file, sc, x=x_bc)
       case ('FGONG')
          call read_fgong_model(file, data_format, sc, x=x_bc)
       case default
          $ABORT(Invalid file_format)
       end select

       allocate(ml, SOURCE=sc)

    case ('POLY')

       $if($HDF5)
       call read_poly_model(file, deriv_type, pc, x=x_bc)
       $else
       $ABORT(No HDF5 support, therefore cannot read POLY files)
       $endif

       allocate(ml, SOURCE=pc)

    case ('HOM')

       hc = hom_model_t(Gamma_1, Omega_rot)

       allocate(ml, SOURCE=hc)

    case default

       $ABORT(Invalid model_type)

    end select

    ! Finish

    return

  end subroutine read_model

!****

  subroutine read_constants (unit)

    integer, intent(in) :: unit

    integer :: n_cn

    namelist /constants/ G_GRAVITY, C_LIGHT, A_RADIATION, &
                         M_SUN, R_SUN, L_SUN

    ! Count the number of constants namelists

    rewind(unit)

    n_cn = 0

    count_loop : do
       read(unit, NML=constants, END=100)
       n_cn = n_cn + 1
    end do count_loop

100 continue

    $ASSERT(n_cn == 1,Input file should contain exactly one &constants namelist)

    ! Read constants

    rewind(unit)
    read(unit, NML=constants)

    ! Finish

    return

  end subroutine read_constants

!****

  subroutine read_modepar (unit, mp)

    integer, intent(in)                       :: unit
    type(modepar_t), allocatable, intent(out) :: mp(:)

    integer                :: n_mp
    integer                :: i
    integer                :: l
    integer                :: m
    integer                :: n_pg_min
    integer                :: n_pg_max
    character(LEN(mp%tag)) :: tag

    namelist /mode/ l, m, n_pg_min, n_pg_max, tag

    ! Count the number of mode namelists

    rewind(unit)

    n_mp = 0

    count_loop : do
       read(unit, NML=mode, END=100)
       n_mp = n_mp + 1
    end do count_loop

100 continue

    ! Read mode parameters

    rewind(unit)

    allocate(mp(n_mp))

    read_loop : do i = 1,n_mp

       l = 0
       m = 0

       n_pg_min = -HUGE(0)
       n_pg_max = HUGE(0)

       tag = ''

       read(unit, NML=mode)

       ! Initialize the modepar

       mp(i) = modepar_t(l=l, m=m, n_pg_min=n_pg_min, n_pg_max=n_pg_max, tag=tag)

    end do read_loop

    ! Finish

    return

  end subroutine read_modepar

!****

  subroutine read_oscpar (unit, op)

    integer, intent(in)                      :: unit
    type(oscpar_t), allocatable, intent(out) :: op(:)

    integer                              :: n_op
    integer                              :: i
    character(LEN(op%rotation_method))   :: rotation_method
    character(LEN(op%variables_type))    :: variables_type
    character(LEN(op%inner_bound_type))  :: inner_bound_type
    character(LEN(op%outer_bound_type))  :: outer_bound_type
    character(LEN(op%inertia_norm_type)) :: inertia_norm_type
    character(LEN(op%tag_list))          :: tag_list
    logical                              :: reduce_order
    logical                              :: nonadiabatic
    real(WP)                             :: x_ref

    namelist /osc/ x_ref, rotation_method, inner_bound_type, outer_bound_type, variables_type, &
         inertia_norm_type, tag_list, reduce_order, nonadiabatic

    ! Count the number of osc namelists

    rewind(unit)

    n_op = 0

    count_loop : do
       read(unit, NML=osc, END=100)
       n_op = n_op + 1
    end do count_loop

100 continue

    ! Read oscillation parameters

    rewind(unit)

    allocate(op(n_op))

    read_loop : do i = 1,n_op

       x_ref = HUGE(0._WP)

       rotation_method = 'NULL'
       variables_type = 'DZIEM'
       inner_bound_type = 'REGULAR'
       outer_bound_type = 'ZERO'
       inertia_norm_type = 'BOTH'
       tag_list = ''

       nonadiabatic = .FALSE.
       reduce_order = .TRUE.

       read(unit, NML=osc)

       ! Initialize the oscpar

       op(i) = oscpar_t(x_ref=x_ref, rotation_method=rotation_method, variables_type=variables_type, &
                        inner_bound_type=inner_bound_type, outer_bound_type=outer_bound_type, &
                        inertia_norm_type=inertia_norm_type, tag_list=tag_list, &
                        nonadiabatic=nonadiabatic, reduce_order=reduce_order)

    end do read_loop

    ! Finish

    return

  end subroutine read_oscpar

!****

  subroutine read_numpar (unit, np)

    integer, intent(in)                      :: unit
    type(numpar_t), allocatable, intent(out) :: np(:)

    integer                        :: n_np
    integer                        :: i
    integer                        :: n_iter_max
    logical                        :: deflate_roots
    character(LEN(np%ivp_solver))  :: ivp_solver
    character(LEN(np%matrix_type)) :: matrix_type
    character(LEN(np%tag_list))    :: tag_list

    namelist /num/ n_iter_max, deflate_roots, &
         ivp_solver, matrix_type, tag_list

    ! Count the number of num namelists

    rewind(unit)

    n_np = 0

    count_loop : do
       read(unit, NML=num, END=100)
       n_np = n_np + 1
    end do count_loop

100 continue

    ! Read numerical parameters

    rewind(unit)

    allocate(np(n_np))

    read_loop : do i = 1,n_np

       n_iter_max = 50

       deflate_roots = .TRUE.

       ivp_solver = 'MAGNUS_GL2'
       matrix_type = 'BLOCK'
       tag_list = ''

       read(unit, NML=num)

       ! Initialize the numpar

       np(i) = numpar_t(n_iter_max=n_iter_max, deflate_roots=deflate_roots, &
                        ivp_solver=ivp_solver, matrix_type=matrix_type, tag_list=tag_list)

    end do read_loop

    ! Finish

    return

  end subroutine read_numpar

!****

  $define $READ_GRIDPAR $sub

  $local $NAME $1

  subroutine read_${NAME}_gridpar (unit, gp)

    integer, intent(in)                       :: unit
    type(gridpar_t), allocatable, intent(out) :: gp(:)

    integer                     :: n_gp
    integer                     :: i
    real(WP)                    :: alpha_osc
    real(WP)                    :: alpha_exp
    real(WP)                    :: alpha_thm
    real(WP)                    :: alpha_str
    real(WP)                    :: s
    integer                     :: n
    character(LEN(gp%file))     :: file
    character(LEN(gp%op_type))  :: op_type
    character(LEN(gp%tag_list)) :: tag_list

    namelist /${NAME}_grid/ alpha_osc, alpha_exp, alpha_thm, alpha_str, s, n, file, op_type, tag_list

    ! Count the number of grid namelists

    rewind(unit)

    n_gp = 0

    count_loop : do
       read(unit, NML=${NAME}_grid, END=100)
       n_gp = n_gp + 1
    end do count_loop

100 continue

    ! Read grid parameters

    rewind(unit)

    allocate(gp(n_gp))

    read_loop : do i = 1, n_gp

       alpha_osc = 0._WP
       alpha_exp = 0._WP
       alpha_thm = 0._WP
       alpha_str = 0._WP

       s = 0._WP

       n = 0

       file = ''

       op_type = 'CREATE_CLONE'
       tag_list = ''

       read(unit, NML=${NAME}_grid)

       ! Initialize the gridpar

       gp(i) = gridpar_t(alpha_osc=alpha_osc, alpha_exp=alpha_exp, alpha_thm=alpha_thm, alpha_str=alpha_str, &
                         s=s, n=n, file=file, op_type=op_type, tag_list=tag_list)

    end do read_loop

    ! Finish

    return

  end subroutine read_${NAME}_gridpar

  $endsub

  $READ_GRIDPAR(shoot)
  $READ_GRIDPAR(recon)

!****

  subroutine read_scanpar (unit, sp)

    integer, intent(in)                       :: unit
    type(scanpar_t), allocatable, intent(out) :: sp(:)

    integer                       :: n_sp
    integer                       :: i
    real(WP)                      :: freq_min
    real(WP)                      :: freq_max
    integer                       :: n_freq
    character(LEN(sp%freq_units)) :: freq_units
    character(LEN(sp%freq_frame)) :: freq_frame
    character(LEN(sp%grid_type))  :: grid_type
    character(LEN(sp%grid_frame)) :: grid_frame
    character(LEN(sp%tag_list))   :: tag_list

    namelist /scan/ freq_min, freq_max, n_freq, freq_units, freq_frame, &
         grid_type, grid_frame, tag_list

    ! Count the number of scan namelists

    rewind(unit)

    n_sp = 0

    count_loop : do
       read(unit, NML=scan, END=100)
       n_sp = n_sp + 1
    end do count_loop

100 continue

    ! Read scan parameters

    rewind(unit)

    allocate(sp(n_sp))

    read_loop : do i = 1, n_sp

       freq_min = 1._WP
       freq_max = 10._WP
       n_freq = 10
          
       freq_units = 'NONE'
       freq_frame = 'INERTIAL'

       grid_type = 'LINEAR'
       grid_frame = 'INERTIAL'

       tag_list = ''

       read(unit, NML=scan)

       ! Initialize the scanpar

       sp(i) = scanpar_t(freq_min=freq_min, freq_max=freq_max, n_freq=n_freq, &
                         freq_units=freq_units, freq_frame=freq_frame, &
                         grid_type=grid_type, grid_frame=grid_frame, &
                         tag_list=tag_list)

    end do read_loop

    ! Finish

    return

  end subroutine read_scanpar

!****

  subroutine read_outpar (unit, up)

    integer, intent(in)         :: unit
    type(outpar_t), intent(out) :: up

    integer                                :: n_up
    character(LEN(up%freq_units))          :: freq_units
    character(LEN(up%freq_frame))          :: freq_frame
    character(LEN(up%summary_file))        :: summary_file
    character(LEN(up%summary_file_format)) :: summary_file_format
    character(LEN(up%summary_item_list))   :: summary_item_list
    character(LEN(up%mode_prefix))         :: mode_prefix
    character(LEN(up%mode_template))       :: mode_template
    character(LEN(up%mode_file_format))    :: mode_file_format
    character(LEN(up%mode_item_list))      :: mode_item_list
    logical                                :: prune_modes

    namelist /output/ freq_units, freq_frame, summary_file, summary_file_format, summary_item_list, &
                      mode_prefix, mode_template, mode_file_format, mode_item_list, prune_modes

    ! Count the number of output namelists

    rewind(unit)

    n_up = 0

    count_loop : do
       read(unit, NML=output, END=100)
       n_up = n_up + 1
    end do count_loop

100 continue

    $ASSERT(n_up == 1,Input file should contain exactly one &output namelist)

    ! Read output parameters

    freq_units = 'NONE'
    freq_frame = 'INERTIAL'

    summary_file = ''
    summary_file_format = 'HDF'
    summary_item_list = 'l,n_pg,omega,freq'
    
    mode_prefix = ''
    mode_template = ''
    mode_file_format = 'HDF'
    mode_item_list = TRIM(summary_item_list)//',x,xi_r,xi_h'

    prune_modes = .FALSE.

    rewind(unit)
    read(unit, NML=output)

    ! Initialize the outpar

    up = outpar_t(freq_units=freq_units, freq_frame=freq_frame, &
                  summary_file=summary_file, summary_file_format=summary_file_format, summary_item_list=summary_item_list, &
                  mode_prefix=mode_prefix, mode_template=mode_template, mode_file_format=mode_file_format, mode_item_list=mode_item_list, &
                  prune_modes=prune_modes)

    ! Finish

    return

  end subroutine read_outpar

end module gyre_input
