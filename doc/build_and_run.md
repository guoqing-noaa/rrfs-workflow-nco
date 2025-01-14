# 1. Build
`git clone -b rrfs-mpas-jedi --recursive git@github.com:NOAA-EMC/rrfs-workflow.git`

`cd sorc` and run the following command to build the system:
```
build.all
```

The above script compiles WPS, MPAS, MPASSIT, RDASApp and UPP simultaneously.  
Build logs for each component can be found under the current directory:
```
log.build.mpas
log.build.rdas
log.build.wps
log.build.mpassit
log.build.upp
```

and executables can be found under `../exec`:
```
ungrib.x
init_atmosphere_model.x
atmosphere_model.x
mpasjedi_variational.x
bufr2ioda.x
mpassit.x
upp.x
```

# 2. Setup and run experiments:
### 2.1. copy and modify exp.setup
```
cd workflow
cp exp/exp.setup .
vi exp.setup # modify directories, accounts, etc
```
In retro runs, for simplicity, `OPSROOT` provides a top directory for `COMROOT`, `DATAROOT` and `EXPDIR`. But this is NOT a must and you may set them separately without a shared top directory.
    
`setup_rocoto.py` will smartly computes CYCLEDEFS based on the `REALTIME`, `REALTIME_DAYS`, `RETRO_PERIOD` settings.  
`RETRO_CYCLETHROTTLE` and `RETRO_TASKTHROTTLE` can be modified as needed.

Refer to [this guide](https://github.com/NOAA-EMC/rrfs-workflow/wiki/deploy-a-realtime-run-in-Jet) for setting up realtime runs. Note: realtime runs under role accounts should be coordinated with the POC of each realtime run.

### 2.2 setup_rocoto.py
```
./setup_rocoto.py
```   
    
This Python script creates an experiment directory (i.e. `EXPDIR`), writes out a runtime version of `exp.setup` under EXPDIR, and  then copies runtime config files from `HOMErrfs/parm` to `EXPDIR`.
       
Users usually need to set up `ACCOUNT`, `QUEUE`, `PARTITION`, or `RESERVATION` by modifying `config_resources/config.${machine}` or you may export those variables in the current environment before running setp_exp.py, or export those variables in `exp.setup`.  
    
The workflow uses a cascade config structure to separate concerns so that a task/job/application/function_group only defines relevant environmental variables required in runtime. Refer to [this guide](https://github.com/NOAA-EMC/rrfs-workflow/wiki/The-cascade-config-structure) for more information.

### 2.3 run and monitor experiments using rocoto commands

Go to `EXPDIR`, open `rrfs.xml`, and make sure it has all the required tasks and settings.
    
Use `./run_rocoto.sh` to run the experiment. Add an entry to your crontab similar to the following to run the experiment continuously.
```
*/5 * * * * /home/role.rtrr/RRFS/1.0.1/conus3km/run_rocoto.sh
```
Check the first few tasks/cycles to make sure everything works well. You may use [this handy rocoto tool](https://github.com/rrfsx/qrocoto/wiki/qrocoto) to check the workflow running status.

### note
The workflow depends on the environmental variables. If your environment defines and exports rrfs-workflow-specific environmental variables in an unexpected way or your environment is corrupt, the setup step may fail or generate unexpected results. Check the `rrfs.xml` file before `run_rocoto.sh`. Starting from a fresh terminal or `module purge` usually solves the above problem.


