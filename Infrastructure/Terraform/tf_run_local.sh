#!/bin/bash

# make the script executable: chmod +x tf_run_local.sh
# run the script: ./tf_run_local.sh <command> <folder_name>
# This script is used to format, validate, plan, apply and destroy Terraform resources locally.
# It also runs tflint and checkov for linting and security checks.

# Prerequisites:
# terraform installation: brew install terraform
# tflint installation: curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
# checkov installation: brew install checkov

TF_COMMAND=$1
FOLDER_NAME=$2

if [ "$TF_COMMAND" == "plan" ]; then
    echo ">> Running Terraform format <<"
    terraform -chdir=$(pwd)/$FOLDER_NAME fmt -recursive
    echo ">> Running Terraform init <<"
    terraform -chdir=$(pwd)/$FOLDER_NAME init -reconfigure -upgrade # reconfigures the backend and upgrades providers if needed
    echo ">> Running Terraform validate <<"
    terraform -chdir=$(pwd)/$FOLDER_NAME validate
    echo ">> Running Terraform plan <<"
    terraform -chdir=$(pwd)/$FOLDER_NAME plan
elif [ "$TF_COMMAND" == "apply" ]; then
    terraform -chdir=$(pwd)/$FOLDER_NAME fmt -recursive
    terraform -chdir=$(pwd)/$FOLDER_NAME init -reconfigure -upgrade # reconfigures the backend and upgrades providers if needed
    terraform -chdir=$(pwd)/$FOLDER_NAME validate
    terraform -chdir=$(pwd)/$FOLDER_NAME apply #--auto-approve
elif [ "$TF_COMMAND" == "destroy" ]; then
    terraform -chdir=$(pwd)/$FOLDER_NAME destroy
elif [ "$TF_COMMAND" == "validate" ]; then
    echo ">> Running Terraform format <<"
    terraform -chdir=$(pwd)/$FOLDER_NAME fmt -recursive
    echo ">> Running Terraform init <<"
    terraform -chdir=$(pwd)/$FOLDER_NAME init -reconfigure -upgrade # reconfigures the backend and upgrades providers if needed
    echo ">> Running Terraform validate <<"
    terraform -chdir=$(pwd)/$FOLDER_NAME validate
    echo ">> Running TFLint <<"
    tflint --init
    tflint --chdir=$(pwd)/$FOLDER_NAME --recursive --format compact
    echo ">> Running Checkov <<"
    checkov -d $(pwd)/$FOLDER_NAME --framework terraform
else
    echo "Valid commands are: plan, apply, destroy or validate. Example: ./tf_run_local.sh plan <folder_name>"
fi
