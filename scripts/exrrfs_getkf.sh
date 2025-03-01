#!/usr/bin/env bash
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]${id}: '
set -x

cpreq=${cpreq:-cpreq}
prefix=${EXTRN_MDL_SOURCE%_NCO} # remove the trailing '_NCO' if any
cd ${DATA}

start_time=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H:%M:%S) 
timestr=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H.%M.%S) 
#
ln -snf ${FIXrrfs}/physics/${PHYSICS_SUITE}/* .
ln -snf ${FIXrrfs}/meshes/${MESH_NAME}.ugwp_oro_data.nc ./ugwp_oro_data.nc
zeta_levels=${EXPDIR}/config/ZETA_LEVELS.txt
nlevel=$(wc -l < ${zeta_levels})
ln -snf ${FIXrrfs}/meshes/${MESH_NAME}.invariant.nc_L${nlevel}_${prefix} ./invariant.nc
mkdir -p graphinfo stream_list
ln -snf ${FIXrrfs}/graphinfo/* graphinfo/
ln -snf ${FIXrrfs}/stream_list/${PHYSICS_SUITE}/* stream_list/
${cpreq} ${FIXrrfs}/jedi/obsop_name_map.yaml .                  
${cpreq} ${FIXrrfs}/jedi/keptvars.yaml .              
${cpreq} ${FIXrrfs}/jedi/geovars.yaml . 
#
# create data directory 
#
mkdir -p data; cd data
mkdir -p obs ens
#
# copy observations files
#
cp ${COMOUT}/ioda_bufr/${IODA_BUFR_WGF}/* obs/.
#
# determine whether to begin new cycles and link correct ensembles
#
if [[ -r "${UMBRELLA_PREP_IC_DATA}/mem001/init.nc" ]]; then
  start_type='cold'
  do_DAcycling='false'
  initial_file='init.nc'
else
  start_type='warm'
  do_DAcycling='true'
  initial_file='mpasin.nc'
fi
# link ensembles to data/ens/
for i in $(seq -w 001 ${ENS_SIZE}); do
  ln -snf ${UMBRELLA_PREP_IC_DATA}/mem${i}/${initial_file} ens/mem${i}.nc
done
#
# enter the run directory
#
cd ${DATA}
#
# generate namelist, streams, and getkf.yaml on the fly
run_duration=1:00:00
physics_suite=${PHYSICS_SUITE:-'mesoscale_reference'}
jedi_da="true" #true
pio_num_iotasks=${NODES}
pio_stride=${PPN}
if [[ "${MESH_NAME}" == "conus12km" ]]; then
  dt=60
  substeps=2
  radt=30
elif [[ "${MESH_NAME}" == "conus3km" ]]; then
  dt=20
  substeps=4
  radt=15
else
  echo "Unknown MESH_NAME, exit!"
  err_exit
fi
file_content=$(< ${PARMrrfs}/${physics_suite}/namelist.atmosphere) # read in all content
eval "echo \"${file_content}\"" > namelist.atmosphere
${cpreq} ${PARMrrfs}/streams.atmosphere.getkf streams.atmosphere
analysisDate=""${CDATE:0:4}-${CDATE:4:2}-${CDATE:6:2}T${CDATE:8:2}:00:00Z""
CDATEm2=$($NDATE -2 ${CDATE})
beginDate=""${CDATEm2:0:4}-${CDATEm2:4:2}-${CDATEm2:6:2}T${CDATEm2:8:2}:00:00Z""
#
# generate getkf.yaml based on how YAML_GEN_METHOD is set
case ${YAML_GEN_METHOD:-1} in
  1) # from ${PARMrrfs}
    sed -e "s/@analysisDate@/${analysisDate}/" -e "s/@beginDate@/${beginDate}/" \
    ${PARMrrfs}/getkf_${TYPE}.yaml > getkf.yaml
    ;;
  2) # cat together from inside sorc/RDASApp
    source ${USHrrfs}/yaml_cat_together.sh
    ;;
  3) # JCB
    source ${USHrrfs}/yaml_jcb.sh
    ;;
  *)
    echo "unknown YAML_GEN_METHOD:${YAML_GEN_METHOD}"
    err_exit
    ;;
esac

if [[ ${start_type} == "cold" ]]; then
  exit 0 #gge.tmp.debug need more time to figure out cold start DA
fi
# run mpasjedi_enkf.x
export OOPS_TRACE=1
export OMP_NUM_THREADS=1
ulimit -s unlimited
ulimit -v unlimited
ulimit -a

source prep_step
${cpreq} ${EXECrrfs}/mpasjedi_enkf.x .
${MPI_RUN_CMD} ./mpasjedi_enkf.x getkf.yaml log.out
# check the status
export err=$?
err_chk
#
# move jdiag* files to the umbrella directory if observer
if [[ "${TYPE}" == "observer" ]]; then
  mv jdiag* ${UMBRELLA_GETKF_DATA}/.
fi
