#!/usr/bin/sh
# Merge monthly NEMO files to annual ones for barakuda

YR=$1
EXP=EE02
GRID=ORCA1.L75

for MOD in icemod grid_T grid_U grid_V
do
    cdo mergetime /lustre/tmp/${USER}/${EXP}/output/nemo/???/EE02_1m_${YR}????_${YR}????_${MOD}.nc ${GRID}-${EXP}_1m_${YR}0101_${YR}1231_${MOD}.nc
done
