# Automated SAP Deployments in Azure Cloud

Master Branch's status: [![Build Status](https://travis-ci.org/Azure/sap-hana.svg?branch=master)](https://travis-ci.org/Azure/sap-hana)

This repository contains a set of highly customizable templates that can be used to automatically deploy complex SAP landscapes in the Azure Cloud.
The templates are split into:
* **Terraform modules**
which deploy the infrastructure components (such as VMs, network, storage) in Azure and then call the:
* **Ansible playbooks**
which run different roles to install and configure SAP HANA and required applications on the already deployed infrastructure.

 ![image](https://raw.githubusercontent.com/Azure/sap-hana/5d2e36d4b80f13980e85af2bc67ff32819c14f8c/template-hapair.png)
 ![image](https://raw.githubusercontent.com/Azure/sap-hana/5d2e36d4b80f13980e85af2bc67ff32819c14f8c/shine-dashboard.png)

## Table of contents

- [Scenarios](#scenarios)
- [Usage](#usage)
- [Getting Started](#getting-started)
- [Supported Applications](#supported-applications)
- [Required SAP Downloads](#required-sap-downloads)
- [License & Copyright](#license--copyright)
- [Contact](#contact)

## Scenarios

#### [HANA single-node instance](deploy/vm/modules/single_node_hana)
- single-node HANA instance

#### [HANA high-availability pair](deploy/vm/modules/ha_pair)
- single-node HANA instance, two-tier [HSR](# "HANA System Replication") (primary/secondary)
- Pacemaker high-availability cluster, fully configured with [SBD](# "STONITH by device") and SAP/Azure resource agents


## Usage

A typical deployment lifecycle will require the following steps:
* [**Preparing your Azure Cloud Shell**](#preparing-your-azure-cloud-shell) (this has to be done only once)
* [**Getting the SAP packages**](#getting-the-sap-packages)
* [**Adjusting the templates**](#adjusting-the-templates)
* [**Running the deployment**](#running-the-deployment)
* [**Verifying the deployment**](#verifying-the-deployment)
* [**Deleting the deployment**](#deleting-the-deployment) (optional)


## Getting Started

In this simple example, we'll deploy a simple single-node SAP HANA instance (specifically, HANA DB 1.0 SPS12 PL17).

#### Preparing your Azure Cloud Shell
1. From your Azure Portal, open your Cloud Shell (`>_` button in top bar).

2. Clone this repository:

    ```sh
    git clone https://github.com/Azure/sap-hana.git
    ```


#### Getting the SAP packages
3. Navigate to the [SAP Software Download Center (SWDC)](https://launchpad.support.sap.com/#/softwarecenter).

4. Search for the following packages required for the single-node HANA scenario and download them to your local machine:

| SWDC filename | Package name | OS | Version | Template parameter |
| ------------- | ------------ | -- | ------- | ------------------ |
| `SAPCAR_1110-80000935.EXE` | SAPCAR | Linux x86_64 | 7.21 | `url_sap_sapcar` |
| `IMDB_SERVER100_122_17-10009569.SAR` | HANA DB Server | Linux x86_64 | 122.17 (SPS12) for HANA DB 1.00 | `url_sap_hdbserver` |

*(**Note**: See the section on [**Required SAP Downloads**](#required-sap-downloads) for a full list of SAP packages, if you want to install additional applications on top of HANA, such as XSA.)*

5. In the Azure Portal, create a **Storage Account**.
*(**Note:** Please make sure to choose a region close to you to improve transfer speed; the SAP bits are quite large.)*

6. In the storage account you just created, create a new **Blob Storage**.

7. In the new Blob Storage that you just created, create a new **Container** and name it `sapbits`.

8. Upload each of the SAP packages you downloaded in step 2 and take note of the download URL.


#### Adjusting the templates

9. Change into the directory for the HANA single-node scenario:

    ```sh
    cd sap-hana/deploy/vm/modules/single_node_hana/
    ```

10. Use a text editor to create a Terraform variables file `terraform.tfvars`, adapting the download URLs accordingly:

    ```python
    # Azure region to deploy resource in; please choose the same region as your storage from step 3 (example: "westus2")
    az_region = "westus2"

    # Name of resource group to deploy (example: "demo1")
    az_resource_group = "demo1"

    # Unique domain name for easy VM access (example: "hana-on-azure1")
    az_domain_name = "hana-on-azure1"
 
    # Set your Azure service principal id.
    azure_service_principal_id = "XXX"
 
    # Set your Azure service principal password
    azure_service_principal_pw = "XXX"

    # Size of the VM to be deployed (example: "Standard_E8s_v3")
    # For HANA platform edition, a minimum of 32 GB of RAM is recommended
    vm_size = "Standard_E8s_v3"

    # Path to the public SSH key to be used for authentication (e.g. "~/.ssh/id_rsa.pub")
    sshkey_path_public = "~/.ssh/id_rsa.pub"

    # Path to the corresponding private SSH key (e.g. "~/.ssh/id_rsa")
    sshkey_path_private = "~/.ssh/id_rsa"

    # OS user with sudo privileges to be deployed on VM (e.g. "demo")
    vm_user = "demo"

    # SAP system ID (SID) to be used for HANA installation (example: "HN1")
    sap_sid = "HN1"

    # SAP instance number to be used for HANA installation (example: "01")
    sap_instancenum = "01"

    # URL to download SAPCAR binary from (see step 6)
    url_sap_sapcar = "https://XXX"

    # URL to download HANA DB server package from (see step 6)
    url_sap_hdbserver = "https://XXX"

    # Password for the OS sapadm user
    pw_os_sapadm = "XXX"

    # Password for the OS <sid>adm user
    pw_os_sidadm = "XXX"

    # Password for the DB SYSTEM user
    # (In MDC installations, this will be for SYSTEMDB tenant only)
    pw_db_system = "XXX"

    # Password for the DB XSA_ADMIN user
    pwd_db_xsaadmin = "XXX"

    # Password for the DB SYSTEM user for the tenant DB (MDC installations only)
    pwd_db_tenant = "XXX"

    # Password for the DB SHINE_USER user (SHINE demo content only)
    pwd_db_shine = "XXX"

    # e-mail address used for the DB SHINE_USER user (SHINE demo content only)
    email_shine = "shine@myemailaddress.com"

    # Set this flag to true when installing HANA 2.0 (or false for HANA 1.0)
    useHana2 = false

    # Set this flag to true when installing the XSA application server
    install_xsa = false

    # Set this flag to true when installing SHINE demo content (requires XSA)
    install_shine = false

    # Set this flag to true when installing Cockpit (requires XSA)
    install_cockpit = false
    ```


#### Running the deployment

11. Log into your Azure subscription and configure Ansible and Terraform:

    ```sh
    az login
    ```

    Configure Ansible:
    ```sh
    export AZURE_SUBSCRIPTION_ID='XXX'
    export AZURE_CLIENT_ID='XXX'
    export AZURE_SECRET='XXX'
    export AZURE_TENANT='XXX'
    ```

    Configure Terraform:
    ```sh
    export ARM_SUBSCRIPTION_ID='XXX'
    export ARM_TENANT_ID='XXX'
    export ARM_CLIENT_ID='XXX'
    export ARM_CLIENT_SECRET='XXX'
    ```

    *(**Note:** Please note that you will need to create a service principal. If you don't have a service principal, please follow the instructions to create one, [How to create a service principal](https://docs.microsoft.com/en-us/cli/azure/create-an-azure-service-principal-azure-cli?toc=%2Fen-us%2Fazure%2Fazure-resource-manager%2Ftoc.json&bc=%2Fen-us%2Fazure%2Fbread%2Ftoc.json&view=azure-cli-latest))*

12. Trigger the deployment:

    ```sh
    terraform apply
    ```

13. When prompted if you want to deploy the resources, answer `yes`. The deployment will start and take approx. 30 minutes (actual times may vary depending on region and other parameters).

14. Once the deployment has finished, take note of the last three lines on your console; they should look like this:

    ```sh
    Apply complete! Resources: 19 added, 0 changed, 0 destroyed.
    
    Outputs:
    
    ip = Connect using tniek@xs1-db0-tniek-xs1.westus2.cloudapp.azure.com
    ```


#### Verifying the deployment

15. Connect to your newly deployed HANA instance via SSH:

16. Switch to the <sid>adm user:

    ```sh
    sudo su -
    su - xs1adm
    ```

17. Run `hdbsql` to execute a simple query:

    ```sh
    hdbsql -i 01 -u SYSTEM -p Initial1 "SELECT CURRENT_TIME FROM DUMMY"
    ```


#### Deleting the deployment

18. If you don't need the deployment anymore, you can remove it just as easily.
In your Azure Cloud Shell, run the following command to remove all deployed resources:

    ```sh
    terraform destroy
    ```

## Supported Applications

Currently, the templates are capable of deploying the following applications on top of the HANA base install:
#### XSA
- [SAP HANA Cockpit](https://help.sap.com/viewer/6b94445c94ae495c83a19646e7c3fd56/2.0.03/en-US/da25cad976064dc0a24a1b0ee9b62525.html)
- [SHINE Demo Model](https://blogs.saphana.com/2014/03/10/shine-sap-hana-interactive-education/)

## Required SAP Downloads

Depending on your application requirements, you may need to download additional SAP packages and adjust the templates accordingly:

| Name | OS | Version | SWDC filename | Scenario | Template parameter |
| ---- | -- | ------- | ------------- | ---------| ------------------ |
| SAPCAR | Linux x86_64 | 7.21 | `SAPCAR_1110-80000935.EXE` | All | `url_sap_sapcar` |
| SAPCAR | Windows 64-bit | 7.21 | `SAPCAR_1110-80000938.EXE` | Windows bastion host | `url_sap_sapcar_win` |
| SAP Host Agent | Linux x86_64 | 7.21 SP36 | `SAPHOSTAGENT36_36-20009394.SAR` | All | `url_sap_hostagent` |
| HANA DB Server | Linux x86_64 | 122.17 (SPS12) for HANA DB 1.00 | `IMDB_SERVER100_122_17-10009569.SAR` | HANA 1.0 landscapes | `url_sap_hdbserver` |
| HANA DB Server | Linux x86_64 | 2.00.32 for HANA DB 2.00 | `IMDB_SERVER20_032_0-80002031.SAR` | HANA 2.0 landscapes | `url_sap_hdbserver` |
| HANA Studio | Windows 64-bit | 122.20 (SPS12) for HANA DB 1.00 | `IMC_STUDIO2_122_20-80000321.SAR` | Windows bastion host | `url_hana_studio` | 
| XS Advanced Runtime | | SP00 Patch87 | `EXTAPPSER00P_87-70001316.SAR` | XSA | `url_xsa_runtime` |
| DI Core | | SP12 Patch9 | `XSACDEVXDI12_9-70001255.ZIP` | XSA | `url_di_core` |
| SAPUI5 | | SP52 Patch19 | `XSACUI5FESV452P_19-70003351.ZIP` | XSA | `url_sapui5` | 
| Portal Services | | SP02 Patch3 | `XSACPORTALSERV02_3-80002098.ZIP` | XSA | `url_portal_services` | 
| XS Services | | SP06 Patch9 | `XSACSERVICES06_9-70002361.ZIP` | XSA | `url_xs_services` |
| HANA Cockpit 2.0 | | SP07 Patch11 | `SAPHANACOCKPIT07_11-70002299.SAR` | XSA + Cockpit | `url_cockpit` |
| SHINE Content (XSA) | | SP05 Patch3 | `XSACSHINE05_3-70002323.ZIP` | XSA + SHINE | `url_shine_xsa` |

## License & Copyright

Copyright © 2018 Microsoft Azure.

Licensed under the [MIT License](LICENSE).

## Contact

We look forward to your feedback and welcome any contributions!

Please freel free to reach out to our team at ![image](http://safemail.justlikeed.net/e/3149a6fc0a17ff3863440aa38a16501b.png).

