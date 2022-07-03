CPU=$1
RAM=$2
provider=$3
instance_regex=${4:-.*}
filename=${5:-./instance_list.txt}
instance_names=()
gcp_region=${7:-us-west2-a}
#needs region variables
create_instance_list() {
    echo "Creating list of instances...."
    headers="instance_name cpus ram providers"
    echo $headers > $filename
    ./gcp_instances.sh $gcp_region >> $filename
    # Reorganize columns to match headers and remove any decimals
    awk '{print $4}' "$filename" | cut -d. -f1 | paste - "$filename" | awk '{print $3,$4,$1,$2}' > "./placeholder.txt"
    mv "./placeholder.txt" "$filename"
    rm -rf "./placeholder.txt"
    #reset headers
    sed -i "1s/.*/$headers/" $filename
    

 }
if [ ! -e $filename ]; then create_instance_list; fi
while IFS=" " read -r -a row
do
    #Convert to ints and round to even numbers
    re='^[0-9]+$'
    if ! [[ ${row[2]} =~ $re ]] ; then continue; fi
        cpu_int=${row[1]%%.*}
        row[1]=$cpu_int
        ram_int=${row[2]%%.*}
        mod=$(($ram_int - $ram_int % 2))
        row[2]=$mod
    
    if [[ ($CPU == ${row[1]} && $RAM == $ram_int && $provider == ${row[-1]}) ]];
    then
        instance_names+=( "${row[0]}")
    #if no match found look for even matches
    elif [[ ($CPU == ${row[1]} && $RAM == $mod && $provider == ${row[-1]}) ]];
    then
        instance_names+=( "${row[0]}")
    fi
    # echo $line
done <  "$filename"
subset=( $( printf '%s\n' "${instance_names[@]}" | grep '$instance_regex' ) )

if [ ${#subset[@]} -gt "0" ]; then instance_name=${subset[0]}; else instance_name=${instance_names[0]}; fi
echo $instance_name


