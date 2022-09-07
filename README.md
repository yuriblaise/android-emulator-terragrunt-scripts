# Android Emulator + Terragrunt
Terragrunt scripts for easily launching multiple android emulator instances in gcp with a CSV.

### Disclaimer
This is very much a proof of concept and builds off of several other open source projects. The bash scripts are fragile but work well enough for demoing. Not suitable for any production environment. 

### How does it work?
The project uses the Infrastructure as Code solution, [Terraform](Terraform.io) to spin up the necessary cloud resources and manage their configurations. 
To minimize the amount of template code [Terragrunt](https://Terragrunt.gruntwork.io/) is used to build common variables across different cloud providers. Included in the repo is a simple CSV parser that passes the necessary values to Terragrunt and stores the config files in a project folder.

## Setup
To successfully run these scripts you will need
* A [GCP Account](https://cloud.google.com/free-trial) 
 * [Terragrunt](https://terragrunt.gruntwork.io/) v0.36.7 or newer
* [Google CLI Terraform Plugin](registry.Terraform.io/hashicorp/google) v4.26.0 or newer  cli

### Installing Terragrunt
The instructions for installing terragrunt can be found [here](https://learn.hashicorp.com/tutorials/terraform/install-cli). The GCP plugin will be installed when `terragrunt init` is run after the project folder is made.

Once Terragrunt and gcloud cli are installed on your system. You can download the Terragrunt dependencies with the commands.

```sh
cd ./gcp
terraform init
```

### Templates and variable files
The terraform files used to spin up each instance are located in `templates/gcp`. Enter you GCP credentials in the `gcp_variables.tf` file or create your own `terraform.tfvars` file and add it to the folder.

To change the default emulator settings, change the values in the `emu_docker_vars.tf` file.


To change the instance or container variables edit the `emu_docker_vars.tf` file.


## Launch instances via CSV
The main value proposition of Terragrunt is being able to easily launch and manage multiple Terraform projects. Combined with a simple CSV parser this makes it easy to launch multiple instances with different configurations using just a CSV. If you're more interested in creating a single instance check out the [android-emulator-terraform](https://github.com/yuriblaise/android-emulator-terraform-scripts) project.

To launch an instance with terragrunt pass a CSV file to the CSV parser with the command 

```sh
CSV_parser.sh gcp_sample.CSV
```

The `CSV_parser.sh`* script needs just 3 columns launch an instance
- Instance CPU 
- Instance RAM
- Cloud Service Provider

To use a TSV or another type of file you can pass the delimeter as the second argument.

```sh
CSV_parser.sh gcp_sample.tsv $'\t'
```

The CSV file can be used to configure the type of instance, emulator, system image, and AVD thats being used. Sample CSV files are included in the repo but for a complete set of possible columns read the descriptions in the `emu_docker_vars.tf`


Note: The CSV parser script is built using vanilla bash/awk and may not handle certain edge cases very well.


### Finding an instance
if the CSV file doesn't contain the column *instance_name* then the number of vCPUs and RAM (GB) can be used to find an instance. The script selects the first instance name that is a match but the [find_instance_name.sh](find_instance_name.sh) script can be used to explore the different types of instances in gcp. The *instance_regex* column can also be used to select a specific instance type from the list.  


### Creating a CSV file
The CSV parser script only needs 3 columns to work; the instance CPU, RAM, and provider. With this the script can select an instance and launch the benchmarks with the default variable values in [benchmark_vars.tf](benchmark_vars.tf). Additional columns can be added to configure Terragrunt variables or for logging in the `settings.txt` file of each benchmark directory.

To enable a new Terraform variable add the variable definition to the [benchmark_vars.tf](benchmark_vars.tf) file and include the variable name as a column in the CSV file. The CSV script will assign each row's value to the variable matching the name of the added column.   

Below are a list of column definitions for the CSV parser script.

```json
{
    CPU: "[required] Number of vCpus an instance should have. Not required if instance_name is set. "
    RAM: "[required] Amount of RAM an instance should have. Not required if instance_name is set. "
    instance_name: "[required] the type of instance you'd like to run the benchmarks on. This value is used across templates to assign the type of instance used.", 
    instance_regex: "Regex for selecting an instance_name for a provider from a list of possible instances. Useful for filtering down to a family of instances, like bare metal.",
    id: "Unique identifier added to folders to prevent duplicates",
}
```

### Finding your project
After the parser is launched it will create a new directory for each row in your CSV, using the column names provided for the name. For example a row with the kvm set to true and an instance that has 4 cores and 16GB RAM will have the folder name `gcp_kvm_true_16GB_4cores`. 

An `id` can also be added column to make identifying projects easier. In the case of duplicate configurations a number following an underscore is added to the folder name.

### Connect automatically
Once the emulator is booted, Terraform will attempt to connect to the cloud emulator with the host local adb server. Connecting via the instance public ip address to tcp port 5555.

### Connecting on Windows with WSL2
You can install and launch these scripts with [Windows Subsystem Linux](). Once Terraform is installed on WSL2. You can launch the instance and connect to it from a Windows host adb server by changing the `adb_keys` and `adb_path` variables to... 

```HCF
variable "adb_keys" {
   description = "path to the folder containing the adb keypair to use with the container and VM"
   type        = string
   default     = "/mnt/c/Users/<windows_username>/.android"
}
variable "adb_path" {
   description = "path of adb executable to use"
   type        = string
   default     = "/mnt/c/Users/<windows_username>/AppData/Local/Android/Sdk/platform-tools/adb.exe" #changed from "adb"
}
```

This assume that adb is installed in the default location on the host. In general as long as the script has access to the local adb keys and executable, the local adb server should be able to connect.


### Upload/Download ADB Keys
If the connection fails the host can connect with any adb instance as long as it has access to the adbkeys and the ip address. By default Terraform will upload the host's adb keys and use them for the cloud emulator. For convienence the keys are also downloaded the gcp folder as `adbkey` and `adbkey.pub` by default.

### Restarting the instance
To prevent [unexpected charges](https://duncanmcclean.com/an-accidental-17k-bill-from-google-cloud-platform-a-story), the script shuts down the VM after its detected that the emulator has been idle for more than 5 minutes. The allowed idle time duration can be changed with the `suspend_minutes` variable, to disable this feature entirely set `auto_suspend` to false. Before shutting down the instance will save a snapshot, the snapshot will automatically be loaded once the VM is restarted.

To restart the instance after its been shut down use the command

```
terraform apply -replace="null_resource.gcp_restart" -var="restart=true"
```

this will restart the instance and relaunch the emulator with the snapshot loaded.

If the instance has already been restarted once set restart to false and before trying again.

```
terraform apply -replace="null_resource.gcp_restart" -var="restart=false" -auto-approve &&
terraform apply -replace="null_resource.gcp_restart" -var="restart=true"
```

### Tear down
To tear down an instance cd to the project folder and use the command

```
terraform destroy -var-file="gcp_vars.tfvars"
```

To tear down all cloud resources for all projects cd to the root folder of the repo and enter the command.

```
terragrunt destroy-all -var-file="gcp_vars.tfvars"
```

### Key variables

If the default setup doesn't fit your needs, the script is pretty easily configurable via the `emu_docker_vars.tf` file.


```HCL
variable "instance_type" {
   description = "cloud provider instance type"
   type        = string
   default     = "c2-standard-4"
}
variable "image_regexp" {
   description = "regexp to select image for docker container"
   type        = string
   default     = "P.*x86_64"
}
variable "adb_keys" {
   description = "path to the folder containing the adb keypair to use with the container and VM"
   type        = string
   default     = "~/.android/"
}
variable "adb_path" {
   description = "path of adb executable to use"
   type        = string
   default     = "adb"
}
variable "auto_suspend" {
  type = bool
  default = true
  description = "Suspend VM after startup"
}
variable "suspend_time" {
  type = number
  default = 5
  description = "Number of minutes to let VM run before suspending"
}
variable "auto_destroy" {
   type = bool
   default = false
   description = "Terraform will destroy all cloud resources after all scripts are done running"
}
```

### To Do
* Pricing Info