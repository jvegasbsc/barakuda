#!/bin/bash

# Lagerloef and colleagues note that:
#
# Evaporation from the global ocean is estimated to be ~ 13 Sv, and the
# precipitation sums to ~ 12.2 Sv. The difference of 0.8 Sv compares with the
# estimate of river input of 1.2 Sv. The apparent imbalance of ~ 0.4 Sv excess
# is smaller than the estimated error bars. Sea level rise due to melting
# glaciers is only ~ 0.01 Sv, so cannot account for the imbalance. Global
# groundwater flows are poorly known but generally estimated to be similarly
# small (Cable et al., 1996). Likely sources of error include scant data in the
# southern oceans and a possible underestimate of evaporation in very-high-wind
# conditions. Other surface flux climatologies display similar patterns, but the
# range of the estimates is quite large and unlikely to be significantly
# improved in the near future.
#
# References: Lagerloef, G., Schmitt, R., Schanze, J. Kao, H-Y, 2010, The Ocean
#             and the Global Water Cycle, Oceanography, Vol.23, No.4
#

#RUN=32bG
#Y_INI_EC=1990
#cyear=2038
#NEMO_OUT_D=/nobackup/rossby15/sm_uflad/run/${RUN}/output/nemo
#DIAG_D=.
#HERE=`pwd`


cmsg="ERROR: $0 => global variable"
if [ -z ${RUN} ]; then echo "${cmsg} RUN is unknown!"; exit ; fi
if [ -z ${Y_INI_EC} ]; then echo "${cmsg} Y_INI_EC is unknown!"; exit ; fi
if [ -z ${cyear} ]; then echo "${cmsg} cyear is unknown!"; exit ; fi
if [ -z ${NEMO_OUT_D} ]; then echo "${cmsg} NEMO_OUT_D is unknown!"; exit ; fi
if [ -z ${DIAG_D} ]; then echo "${cmsg} DIAG_D is unknown!"; exit ; fi


RUN_DIR=`echo ${NEMO_OUT_D} | sed -e "s|/output/nemo||g"`
IFS_OUT_D=`echo ${NEMO_OUT_D} | sed -e "s|/output/nemo|/output/ifs|g"`

echo
echo " RUN_DIR = ${RUN_DIR}"
echo " IFS_OUT_D = ${IFS_OUT_D}"
echo



YDIR=$((${cyear}-${Y_INI_EC}+1))

dir_ece=`printf "%03d" ${YDIR}`
dir_ece=${RUN_DIR}/output/ifs/${dir_ece}

echo ${dir_ece}


F_AREA=${RUN_DIR}/areas.nc
F_MASK=${RUN_DIR}/masks.nc

echo ${F_AREA} ; ls -l ${F_AREA}
echo ${F_MASK} ; ls -l ${F_MASK}


mkdir -p ./IFS

cd ./IFS/

#rm -f *.grb *.nc *.tmp


# Create ifs_area_masked:
#echo
#echo "cdo setmisstoc,0 -ifthen -eqc,0 -selvar,A128.msk ${F_MASK} -selvar,A128.srf ${F_AREA} metrics.nc"
#cdo setmisstoc,0 -ifthen -eqc,0 -selvar,A128.msk ${F_MASK} -selvar,A128.srf ${F_AREA} metrics.nc
#echo
 
ncks -O -h -v A128.msk ${F_MASK} -o metrics.nc
ncrename -h -v A128.msk,mask  metrics.nc

ncks -A -h -v A128.srf ${F_AREA} -o metrics.nc
ncrename -h -v A128.srf,ifs_area_glob metrics.nc

ncwa -h -O -a y metrics.nc -o metrics.nc # remove y of length !

ncap2 -h -A -s "ifs_area_land=mask*ifs_area_glob"      metrics.nc -o metrics.nc
ncap2 -h -A -s "ifs_area_ocean=(1-mask)*ifs_area_glob" metrics.nc -o metrics.nc

# Checking surface of the ocean and continents to be sure...
ncap2 -h -A -s "srf_glob=ifs_area_glob.total(\$x)*1.E-12" metrics.nc -o metrics.nc
ncatted -h -O -a units,srf_glob,o,c,'10^6 km^2' metrics.nc
ncap2 -h -A -s "srf_ocean=ifs_area_ocean.total(\$x)*1.E-12" metrics.nc -o metrics.nc
ncatted -h -O -a units,srf_ocean,o,c,'10^6 km^2' metrics.nc
ncap2 -h -A -s "srf_land=ifs_area_land.total(\$x)*1.E-12" metrics.nc -o metrics.nc
ncatted -h -O -a units,srf_land,o,c,'10^6 km^2' metrics.nc



# Add degenerate time record:
ncecat   -h -O metrics.nc -o metrics.nc
ncrename -h -d record,time metrics.nc


#mv -f metrics.nc ${HERE}/
#exit



for cm in "01" "02" "03" "04" "05" "06" "07" "08" "09" "10" "11" "12"; do

    echo
    echo " do_fwf_series_ifs.sh => ${cyear}/${cm}"

    fgrb=${dir_ece}/ICMGG${RUN}+${cyear}${cm}

    if [ "${cm}" = "01" ]; then
        pptime=$(cdo showtime -seltimestep,1,2 ${fgrb} | tr -s ' ' ':' | awk -F: '{print ($5-$2)*3600+($6-$3)*60+($7-$4)}' )
        if [ $pptime -le 0 ]; then
            pptime=21600 # default 6-hr output timestep
        fi
        echo " pptime = ${pptime} seconds !"
    fi

    FALL=ALL_${RUN}_${cyear}${cm}.nc

    # Extracting variables of interest and converting to netcdf at the same time (keep gaussian-reduced grid!!!)
    echo "cdo -t ecmwf -f nc -selvar,E,LSP,CP ${fgrb} ${FALL}"
    cdo -t ecmwf -f nc -selvar,E,LSP,CP ${fgrb} ${FALL}
    echo "done"; echo

    ncrename -h -O -d rgrid,x ${FALL}


    icpt=0
    for VAR in  "e" "lsp" "cp"; do

        icpt=`expr ${icpt} + 1`

        ftreat=${VAR}_${RUN}_${cyear}${cm}

        BVAR=`echo ${VAR}| tr '[:lower:]' '[:upper:]'`

        # To netcdf monthly:
        echo "ncra -h -O -v ${BVAR} ${FALL} -O ${ftreat}_m.nc"
        ncra -h -O -v ${BVAR} ${FALL} -O ${ftreat}_m.nc
        
        # To m/s:
        echo "ncap2 -h -A -s ${VAR}=${BVAR}/${pptime} ${ftreat}_m.nc -o ${ftreat}.nc"
        ncap2 -h -A -s "${VAR}=${BVAR}/${pptime}" ${ftreat}_m.nc -o ${ftreat}.nc ; rm ${ftreat}_m.nc
        ncatted -O -a units,${VAR},o,c,'m of water / s' ${ftreat}.nc

        # Append ocean mask surface into the file:
        ncks -h -A -v ifs_area_glob  metrics.nc -o ${ftreat}.nc
        ncks -h -A -v ifs_area_ocean metrics.nc -o ${ftreat}.nc
        ncks -h -A -v ifs_area_land  metrics.nc -o ${ftreat}.nc




        isign=1
        if [ "${VAR}" = "e" ]; then isign=-1; fi

        # Multiplying ${VAR} and ifs_area_masked:
        ncap2 -h -A -s "${VAR}2d=(${isign}*ifs_area_ocean*${VAR})"     ${ftreat}.nc -o ${ftreat}.nc
        ncap2 -h -A -s "${VAR}2d_glb=(${isign}*ifs_area_glob*${VAR})"  ${ftreat}.nc -o ${ftreat}.nc
        ncap2 -h -A -s "${VAR}2d_land=(${isign}*ifs_area_land*${VAR})" ${ftreat}.nc -o ${ftreat}.nc

        # Total volume evaporated over ocean during the current month:

        ncap2 -h -A -s "flx_${VAR}_sv=${VAR}2d.total(\$x)*1.E-6"         ${ftreat}.nc -o ${ftreat}.nc
        ncap2 -h -A -s "flx_${VAR}_glb_sv=${VAR}2d_glb.total(\$x)*1.E-6" ${ftreat}.nc -o ${ftreat}.nc
        ncap2 -h -A -s "flx_${VAR}_land_sv=${VAR}2d_land.total(\$x)*1.E-6" ${ftreat}.nc -o ${ftreat}.nc
        ncatted -O -a units,flx_${VAR}_sv,o,c,'Sv'     ${ftreat}.nc
        ncatted -O -a units,flx_${VAR}_glb_sv,o,c,'Sv' ${ftreat}.nc
        ncatted -O -a units,flx_${VAR}_land_sv,o,c,'Sv' ${ftreat}.nc

        ncks -h -A -v flx_${VAR}_sv     ${ftreat}.nc -o final_${cm}.nc
        ncks -h -A -v flx_${VAR}_glb_sv ${ftreat}.nc -o final_${cm}.nc
        ncks -h -A -v flx_${VAR}_land_sv ${ftreat}.nc -o final_${cm}.nc

        # Checking surface of the ocean to be sure...
        #if [ ${icpt} -eq 1 ]; then
        #    ncap2 -h -A -s "srf_ocean=ifs_area_ocean.total(\$x)*1.E-12" ${ftreat}.nc -o ${ftreat}.nc
        #    ncatted -O -a units,srf_ocean,o,c,'10^6 km^2' ${ftreat}.nc
        #    ncks -h -A -v srf_ocean ${ftreat}.nc -o final_${cm}.nc
        #fi

        rm -f ${ftreat}.nc

        # End loop variables
    done

    rm -f ${FALL}

    echo " *** month ${cm} done!"
    echo


done


echo "ncrcat -O final_*.nc -o final.nc"
ncrcat -O final_*.nc -o final.nc

ncap2 -h -O -s "time=array(${cyear}.0416667,0.08333333,\$time)" final.nc -o final.nc
ncatted -O -a units,time,o,c,'years' final.nc

ncap2 -h -A -s "flx_p_sv=flx_cp_sv+flx_lsp_sv" final.nc
ncap2 -h -A -s "flx_emp_sv=flx_e_sv-flx_p_sv"  final.nc

ncap2 -h -A -s "flx_p_glb_sv=flx_cp_glb_sv+flx_lsp_glb_sv" final.nc
ncap2 -h -A -s "flx_emp_glb_sv=flx_e_glb_sv-flx_p_glb_sv"  final.nc

ncap2 -h -A -s "flx_p_land_sv=flx_cp_land_sv+flx_lsp_land_sv" final.nc
ncap2 -h -A -s "flx_emp_land_sv=flx_e_land_sv-flx_p_land_sv"  final.nc


rm -f metrics.nc final_*.nc


#mv -f final.nc ${HERE}/ ; exit


fout=${DIAG_D}/mean_fwf_IFS_${RUN}_global.nc

if [ ! -f ${fout} ]; then
    mv final.nc ${fout}
else
    ncrcat -h -A ${fout} final.nc -o ${fout}
fi
rm -f final.nc

exit
