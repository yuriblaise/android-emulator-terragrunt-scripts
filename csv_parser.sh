#!/bin/bash

# pass actual csv functions through
# get instance_name from find_instance_name.sh
defaults=("instance_type cpus ram provider kvm_on gpu_sku launch_command avd_props avd_config results_dir id")
delimiter=${2:-,}

#Get first line of a file https://stackoverflow.com/a/11099042
header=($(cat $1 | head -n 1))
header=( "${header[@],,}" )

#Check if a variable is an array https://stackoverflow.com/a/27254437
if [[ ${#header[@]} -gt 1 ]]; then
    headerArr=${header[@]}
else
    IFS=$delimiter read -r -a headerArr <<< "$header"
fi

IFS=$'\n'
cols=$(echo ${defaults[@]} ${headerArr[@]} | sed 's/ /\n/g' | sort | uniq -d)
cols=($cols)
rows=($(tail -n +2 $1))
rows=( "${rows[@],,}" )

get_col_index() {
    # echo $(head -1 $2 | sed 's/,/\n/g' | nl | grep -e "$1" | awk '{print $1}')
    local element=$1
    shift
    local arr=("$@")
    for i in "${!arr[@]}";
    do
        if [[ "${arr[$i]}" = "${element}" ]];
        then
            echo $(($i+1))
            break
        fi
    done
}

#Set default values
gpu_sku=0
kvm_on=0
avd_config=""
avd_props=""
avd_name=""
image_regexp=""
emulator_version=""
results_dir=""
provider=settings['provider']
adb=""
command=""
instance_regex=''
id=""
var_file="emu_docker_vars.tf"
tfvar_file="gcp_vars.tfvars"

# Each column is assigned to atleast one array of variable names
# The array is used for setting up the benchmarks and terraform
IFS=' '
results_dir_list='provider avd_name gpu_sku kvm_on id'
results_dir_array=( $results_dir_list )
input_cols="results_dir instance_type"
required_vars=( $input_cols )
optional_vars=("avd_props avd_config gpu_sku adb kvm_on launch_command")
# terraform_vars="results_dir instance_type avd_props avd_config gpu_sku adb kvm_on launch_command destroy"
terraform_vars=$(grep variable $var_file | cut -d'"' -f 2 | tr '\n' ' ')
# terraform_vars=( $terraform_vars )
vm_vars=("image_regexp kvm_on launch_command")

#Create an associative array of the variable values for later logging
declare -A settings
for i in "${cols[@]}"
do
    :
    settings["$i"]=$(get_col_index $i ${headerArr[@]})
done

# Create and launch a terragrunt configuration for each row
# the settings used for each configuration will be saved in the
# Terraform folder for each instance as settings.txt 
# along with log files.

for r in "${rows[@]}"
    do
    :
        # read file line and begin inputting row values
        IFS=$delimiter read -r -a r <<< "$r"
        results_dir="" #reset results_dir value
        provider_idx=${settings["provider"]}
        r_provider=${r[$provider_idx-1]}
        
        #Print out instance and benchmark config values
        echo "Columns: ${cols[@]}"
        echo "ROW: $r"
        echo "PROVIDER: $r_provider"

        # If the results directory is included in row value assign the value
        if [[ ("${cols[@]}" == *"results_dir"*) ]]; then
            results_dir=settings["results_dir"]
        fi
        
        # If result directory has no value create one using the row values
        if [[ results_dir == *""* ]]; then
            for x in "${results_dir_array[@]}"
            do
            :
                if [ -v settings["$x"] ]; then
                    idx="${settings["$x"]}"
                    if [[ "$x" == *"kvm_on"* ]]; then
                        results_dir+="_kvm_${r[$idx-1]}"
                    elif [[ "$x" == *"gpu_sku"* ]]; then
                        results_dir+="_gpu_${r[$idx-1]}"
                    elif [[ "$x" == *"id"* ]]; then
                        results_dir+="_${r[$idx-1]}"
                    else
                        results_dir+="_${r[$idx-1]}"
                    fi
                fi
            done
        fi
        
        # check for RAM & CPU otherwise exit
        if [[ ("${cols[@]}" == *"cpus"* && "${cols[@]}" == *"ram"*) ]];
        then
            ram_idx=$(get_col_index 'ram' ${headerArr[@]})
            cpus_idx=$(get_col_index 'cpus' ${headerArr[@]})

            results_dir+="_${r[$ram_idx-1]}GB"
            results_dir+="_${r[$cpus_idx-1]}cores"

            instance_type=$(./find_instance_name.sh ${r[$cpus_idx-1]} ${r[$ram_idx-1]} $r_provider)
            echo "INSTANCE_TYPE: $instance_type"
            if [ -z "$instance_type" ]; then
                final_results_dir="${results_dir:1}"
                err_msg="No Instance found for ${row[@]} Skipping for now..."
                mkdir -p ./$final_results_dir
                touch ./$final_results_dir/log.txt
                chmod 777 ./$final_results_dir/log.txt
                echo "${r[@]}" >> ./$final_results_dir/log.txt 
                echo "$err_msg" >> ./$final_results_dir/log.txt
                continue
            else
                cols[${#cols[@]}]="instance_type"
                r[${#r[@]}]=$instance_type
                addInstanceType=true #For adding the instance_type to tfvars file
            fi
        fi
        if [[ ("${cols[@]}" == *"launch_command"*) ]];
        then
            echo "custom script being loaded"
        fi
        results_dir="${results_dir:1}"
        if [[ -e $results_dir || -L $results_dir ]] ; then
            i=1
            while [[ -e ${results_dir}_$i || -L ${results_dir}_$i ]] ; do
                ((i++))
            done
            results_dir=${results_dir}_$i
        fi
        echo "Results_Directory: $results_dir"
        mkdir -p ./"$results_dir"
        touch ./"$results_dir"/settings.txt
        chmod 777 ./"$results_dir"/settings.txt
        echo "${cols[@]}" >> ./"$results_dir"/settings.txt
        echo "${r[@]}" >> ./"$results_dir"/settings.txt
        echo "" > ./"$results_dir"/"$tfvar_file"
        for i in "${terraform_vars[@]}"
        do
        :
            if [[ -v settings["$i"] ]]; then
             idx=${settings["$i"]}
             echo "VARIABLES: $i,${r[$idx-1]}"
             echo "$i" = "${r[$idx-1]}" >> ./"$results_dir"/"$tfvar_file"
             fi
        done
        # Add the instance type if not included in the file as a column
        if [[ -v addInstanceType ]]; then
            echo "instance_type = \"${instance_type}\"" >> ./"$results_dir"/"$tfvar_file"
        fi
        cp -a ./"$var_file" ./"$results_dir"/
        cp -a ./templates/$r_provider/. ./"$results_dir"/
        cd ./"$results_dir" || exit
        terragrunt init
        # terragrunt apply -var-file=""$tfvar_file"" -auto-approve 2>&1 | tee terraform_logs.txt &
        echo yes | terragrunt apply -var-file="$tfvar_file" 2>&1 | tee terraform_logs.txt &
        cd ..
    done
    