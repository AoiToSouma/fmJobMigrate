#!/bin/bash

if [ -e ~/"plinode_$(hostname -f)".vars ]; then
    source ~/"plinode_$(hostname -f)".vars
fi
if [ -e ~/"plinode_$(hostname -f)"_bkup.vars ]; then
    source ~/"plinode_$(hostname -f)"_bkup.vars
fi

# Get current user id and store as var
USER_ID=$(getent passwd $EUID | cut -d: -f1)
GROUP_ID=$(getent group $EUID | cut -d: -f1)

SELECT_JOB="SELECT j.id, j.pipeline_spec_id, j.type, j.schema_version, j.name, j.forwarding_allowed, j.max_task_duration,
       f.absolute_threshold, f.contract_address, f.drumbeat_enabled, f.evm_chain_id,
       f.idle_timer_period, f.idle_timer_disabled, f.poll_timer_period,
       f.poll_timer_disabled, f.threshold
  FROM jobs j
  LEFT JOIN flux_monitor_specs f ON j.flux_monitor_spec_id = f.id
 WHERE j.type = 'fluxmonitor';"

SELECT_PIPE="SELECT dot_dag_source FROM pipeline_specs WHERE id ="

FM_BACKUP_FILE="fmjob_backup_"

FUNC_CHECK_DIRS(){
    # Checks if NOT NULL for the 'DB_BACKUP_DIR'variable
    if [ ! -z "$DB_BACKUP_DIR" ] ; then
        #echo "checking DIR vars - apply default directory value..."
    
        DB_BACKUP_DIR="plinode_backups"
    
        # Checks if directory exists & creates if not + sets perms
        # following logic attempts to resolve the leading Root '/' path issue
    
        if [ ! -d "/$DB_BACKUP_DIR" ]; then
            #echo -e "${GREEN} SETTING FOLDER PERMS  ${NC}"
            #echo "checking DIR vars - check directory exists & setting perms..."
            sudo mkdir "/$DB_BACKUP_DIR"
            sudo chown $USER_ID\:$DB_BACKUP_GUSER -R "/$DB_BACKUP_DIR"
            sudo chmod g+rw "/$DB_BACKUP_DIR";
        fi
    else
        #echo
        #echo "checking vars - Detected NULL - setting 'default'value.."
        DB_BACKUP_DIR="plinode_backups"
        #echo "checking vars - var 'DB_BACKUP_DIR' value is now: $DB_BACKUP_DIR"
    
        # adds the variable value to the VARS file
        #echo
        #echo "checking vars - updating file "$PLI_DB_VARS_FILE" variable 'DB_BACKUP_DIR' to: "$DB_BACKUP_DIR""
        sed -i.bak 's/DB_BACKUP_DIR=\"\"/DB_BACKUP_DIR=\"'$DB_BACKUP_DIR'\"/g' ~/$PLI_DB_VARS_FILE
    fi

    if [ ! -d "/$DB_BACKUP_DIR" ]; then
        #echo -e "${GREEN} SETTING FOLDER PERMS  ${NC}"
        #echo "checking DIR vars - check directory exists & setting perms..."
        sudo mkdir "/$DB_BACKUP_DIR"
        sudo chown $USER_ID\:$DB_BACKUP_GUSER -R "/$DB_BACKUP_DIR"
        sudo chmod g+rw "/$DB_BACKUP_DIR";
    fi

    # Updates the 'DB_BACKUP_PATH' & 'DB_BACKUP_OBJ' variable
    DB_BACKUP_PATH="/$DB_BACKUP_DIR"
    sudo chown $USER_ID\:$DB_BACKUP_GUSER -R "/$DB_BACKUP_DIR"
    sudo chmod g+rw "/$DB_BACKUP_DIR"

    DB_BACKUP_OBJ="$DB_BACKUP_PATH/$DB_BACKUP_FNAME"
    CONF_BACKUP_OBJ="$DB_BACKUP_PATH/$NODE_BACKUP_FNAME"

    FM_BACKUP_DIR="$DB_BACKUP_PATH/fm_jobs"
    if [ ! -d "$FM_BACKUP_DIR" ]; then
        sudo mkdir "/$FM_BACKUP_DIR"
        sudo chown $USER_ID\:$DB_BACKUP_GUSER -R "/$FM_BACKUP_DIR"
        sudo chmod g+rw "/$FM_BACKUP_DIR";
    fi

    FM_BACKUP_OBJ="$FM_BACKUP_DIR/$FM_BACKUP_FILE"

    #echo
    #echo "checking vars - exiting directory check & continuing..."
    #sleep 2s

    #echo
    echo "checking vars - your configured node backup PATH is: $DB_BACKUP_PATH"
    sleep 2s
}

FUNC_BACKUP(){
IFS=$'\n'
    fmJobs=$(sudo -u postgres -i psql -qtA -d $DB_NAME -c "$SELECT_JOB")
    for fmJob in ${fmJobs[@]}; do
        jobId=$(echo $fmJob | cut -d'|' -f1)
        pipelineSpecId=$(echo $fmJob | cut -d'|' -f2)
        type=$(echo $fmJob | cut -d'|' -f3)
        schemaVersion=$(echo $fmJob | cut -d'|' -f4)
        name=$(echo $fmJob | cut -d'|' -f5)
        forwardingAllowed=$(echo $fmJob | cut -d'|' -f6)
        maxTaskDuration=$(echo $fmJob | cut -d'|' -f7)
        absoluteThreshold=$(echo $fmJob | cut -d'|' -f8)
        contractAddress=$(echo $fmJob | cut -d'|' -f9)
        drumbeatEnabled=$(echo $fmJob | cut -d'|' -f10)
        evmChainId=$(echo $fmJob | cut -d'|' -f11)
        idleTimerPeriod=$(echo $fmJob | cut -d'|' -f12)
        idleTimerDisabled=$(echo $fmJob | cut -d'|' -f13)
        pollTimerPeriod=$(echo $fmJob | cut -d'|' -f14)
        pollTimerDisabled=$(echo $fmJob | cut -d'|' -f15)
        threshold=$(echo $fmJob | cut -d'|' -f16)

        observationSource=$(sudo  -u postgres -i psql -qtA -d $DB_NAME -c "$SELECT_PIPE$pipelineSpecId;")

        fileName=$FM_BACKUP_OBJ$jobId".toml"
        echo 'type = "'$type'"' > $fileName
        echo 'schemaVersion = '$schemaVersion >> $fileName
        echo 'name = "'$name'"' >> $fileName
        if [ $forwardingAllowed = "f" ]; then
            echo 'forwardingAllowed = false' >> $fileName
        else
            echo 'forwardingAllowed = true' >> $fileName
        fi
        echo 'maxTaskDuration = "'$maxTaskDuration'ns"' >> $fileName
        echo 'absoluteThreshold = '$absoluteThreshold >> $fileName
        checksumAddress=$(node checksumAddress.js $(echo $contractAddress | sed 's/^\\/0/g'))
        echo 'contractAddress = "'$checksumAddress'"' >> $fileName
        if [ $drumbeatEnabled = "f" ]; then
            echo 'drumbeatEnabled = false' >> $fileName
        else
            echo 'drumbeatEnabled = true' >> $fileName
        fi
        echo 'evmChainID = "'$evmChainId'"' >> $fileName
        echo 'idleTimerPeriod = "'$idleTimerPeriod'ns"' >> $fileName
        if [ $idleTimerDisabled = "f" ]; then
            echo 'idleTimerDisabled = false' >> $fileName
        else
            echo 'idleTimerDisabled = true' >> $fileName
        fi
        echo 'pollTimerPeriod = "'$pollTimerPeriod'ns"' >> $fileName
        if [ $pollTimerDisabled = "f" ]; then
            echo 'pollTimerDisabled = false' >> $fileName
        else
            echo 'pollTimerDisabled = true' >> $fileName
        fi
        echo 'threshold = '$threshold >> $fileName
        echo 'observationSource = """' >> $fileName
        echo "$observationSource" >> $fileName
        echo '"""' >> $fileName
    done
}

FUNC_RESTORE(){
    echo
}

FUNC_CHECK_DIRS
FUNC_BACKUP
