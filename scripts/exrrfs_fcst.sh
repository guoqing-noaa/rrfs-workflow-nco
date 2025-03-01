#!/usr/bin/env bash
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]${id}: '
set -x
cpreq=${cpreq:-cpreq}

cd ${DATA}
timestr=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H.%M.%S) 
lbc_interval=${LBC_INTERVAL:-3}
#
# determine time steps and etc according to the mesh
#
if [[ ${MESH_NAME} == "conus12km" ]]; then
  dt=60
  substeps=2
  disp=12000.0
  radt=30
elif [[ ${MESH_NAME} == "conus3km" ]]; then
  dt=20
  substeps=4
  disp=3000.0
  radt=15
else
  echo "Unknown MESH_NAME, exit!"
  err_exit
fi
#
# find forecst length for this cycle
#
fcst_length=${FCST_LENGTH:-1}
fcst_len_hrs_cycles=${FCST_LEN_HRS_CYCLES:-"01 01"}
fcst_len_hrs_thiscyc=$(${USHrrfs}/find_fcst_length.sh "${fcst_len_hrs_cycles}" "${cyc}" "${fcst_length}")
echo "forecast length for this cycle is ${fcst_len_hrs_thiscyc}"
#
# determine whether to begin new cycles
#
if [[ -r "${UMBRELLA_ROOT}/prep_ic/init.nc" ]]; then
  ln -snf ${UMBRELLA_ROOT}/prep_ic/init.nc .
  start_type='cold'
  do_DAcycling='false'
  initial_filename='init.nc'
else
  ln -snf ${UMBRELLA_ROOT}/prep_ic/mpasin.nc .
  start_type='warm'
  do_DAcycling='true'
  initial_filename='mpasin.nc'
fi

#
#  link bdy and fix files
#
ln -snf ${UMBRELLA_ROOT}/prep_lbc/lbc*.nc .

ln -snf ${FIXrrfs}/physics/${PHYSICS_SUITE}/* .
ln -snf ${FIXrrfs}/meshes/${MESH_NAME}.ugwp_oro_data.nc ./ugwp_oro_data.nc
zeta_levels=${EXPDIR}/config/ZETA_LEVELS.txt
nlevel=$(wc -l < ${zeta_levels})
ln -snf ${FIXrrfs}/meshes/${MESH_NAME}.invariant.nc_L${nlevel} ./invariant.nc
mkdir -p graphinfo stream_list
ln -snf ${FIXrrfs}/graphinfo/* graphinfo/
ln -snf ${FIXrrfs}/stream_list/${PHYSICS_SUITE}/* stream_list/

# generate the namelist on the fly
# do_restart already defined in the above
start_time=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H:%M:%S) 
run_duration=${fcst_len_hrs_thiscyc:-1}:00:00
physics_suite=${PHYSICS_SUITE:-'mesoscale_reference'}
jedi_da="true" #true

if [[ "${MESH_NAME}" == "conus12km" ]]; then
  pio_num_iotasks=1
  pio_stride=40
elif [[ "${MESH_NAME}" == "conus3km" ]]; then
  pio_num_iotasks=40
  pio_stride=20
fi
file_content=$(< ${PARMrrfs}/${physics_suite}/namelist.atmosphere) # read in all content
eval "echo \"${file_content}\"" > namelist.atmosphere

# generate the streams file on the fly using sed as this file contains "filename_template='lbc.$Y-$M-$D_$h.$m.$s.nc'"
# lbc_interval is defined in the beginning
restart_interval=${RESTART_INTERVAL:-61}
history_interval=${HISTORY_INTERVAL:-1}
#diag_interval=${DIAG_INTERVAL:-1}
diag_interval=${HISTORY_INTERVAL:-1}
sed -e "s/@restart_interval@/${restart_interval}/" -e "s/@history_interval@/${history_interval}/" \
    -e "s/@diag_interval@/${diag_interval}/" -e "s/@lbc_interval@/${lbc_interval}/" \
    -e "s/@initial_filename@/${initial_filename}/" \
    ${PARMrrfs}/streams.atmosphere  > streams.atmosphere

# run the MPAS model
ulimit -s unlimited
ulimit -v unlimited
ulimit -a
source prep_step
${cpreq} ${EXECrrfs}/atmosphere_model.x .
${MPI_RUN_CMD} ./atmosphere_model.x 
#
# check the status
#
num_err_log=$(ls ./log.atmosphere*.err 2>/dev/null | wc -l)
if (( ${num_err_log} > 0 )) ; then
  echo "FATAL ERROR: MPAS model run failed"
  err_exit
else
  exit 0
fi
