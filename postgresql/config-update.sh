#!/bin/bash
# Description:  Read uncommented parameters from postgresql.conf and transfer them to another one.
# Author:       Lesovsky A.V.
# Usage:        config-update.sh source.conf destination.conf

[[ $# -lt 2 ]] && { echo -e "Usage:\n  $0 source.conf destination.conf"; exit 1; }

srcCfg=$1
destCfg=$2
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

[[ -f $srcCfg ]] || { echo "${red}ERROR:${reset} $srcCfg doesn't exist. Exit."; exit 1; }
[[ -f $destCfg ]] || { echo "${red}ERROR:${reset} $destCfg doesn't exist. Exit."; exit 1; }

export PATH="/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin"

# backup the destination.conf
echo "${green}INFO:${reset} backup $destCfg to $destCfg.backup"
cp $destCfg $destCfg.backup

# do processing
echo "${green}INFO:${reset} processing $destCfg"
grep -oE "^[a-z_\. ]+[ ]*=[ ]*('.*'|[a-z0-9A-Z._-]+)" $srcCfg |while read line;
  do
      # second e-script in sed is used for quoting '|' because that one is used as a separator in the next sed replacing command.
      guc=$(echo $line |cut -d= -f1 |tr -d " "); value=$(echo $line |cut -d= -f2- |sed -e 's/^[ ]*//' -e 's/|/\\|/g' -e 's/&/\\&/g')
      if [[ $(grep -c -w $guc $destCfg) -eq 0 && $guc != *'.'* ]]; then
          echo "${yellow}WARNING:${reset} $destCfg doesn't contain ${red}$guc${reset} (value: $value)"
      else
            # skip version-specific parameters which look like paths and replace others
            if [[ $( echo $value |grep -wE "'.*((8|9)\.[0-9]{1}|1[0-9]{1}).*'" |wc -l) -ne 0 ]];
                then
                    echo "${yellow}WARNING:${reset} Skip transfer of $guc = $value"
                else
                    # replace regular parameters
                    sed -r -i -e "s|^(#\| )?$guc[ ]*=[ ]*('.*'\|[a-z0-9A-Z._-]+)|$guc = $value|g" $destCfg || echo "${red}ERROR:${reset} sed processing failed: $guc = $value"
                    # add extensions related parameters
                    [[ $guc = *'.'* ]] && echo "$guc = $value" >> $destCfg
            fi
      fi
  done

# check for new options
echo "${green}INFO:${reset} $destCfg's new options:"
grep -oE "^[a-z_\. #]+[ ]*=[ ]*('.*'|[a-z0-9A-Z._-]+)" $destCfg |while read line;
    do
        guc=$(echo $line |cut -d= -f1 |tr -d " "#); value=$(echo $line |cut -d= -f2- |sed -e 's/^[ ]*//' -e 's/|/\\|/g')
        if [[ $(grep -c -w $guc $srcCfg) -eq 0 ]]; then
            echo -e "\t$guc = $value"
        fi
    done

# check version-specific values
echo "${red}INFO:${reset} Check the following parameters in $destCfg and fix values if required."
grep -oE "^[a-z_\. ]+[ ]*=[ ]*('.*'|[a-z0-9A-Z._-]+)" $destCfg |while read line;
  do
      guc=$(echo $line |cut -d= -f1 |tr -d " "); value=$(echo $line |cut -d= -f2- |sed -e 's/^[ ]*//')
      if [[ $( echo $value |grep -wE "'.*((8|9)\.[0-9]{1}|10).*'" |wc -l) -ne 0 ]]; then
          echo -e "\t$guc = $value"
      fi
  done
