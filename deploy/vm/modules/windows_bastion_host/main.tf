resource "azurerm_network_security_group" "windows_bastion_nsg" {
  count               = "${var.windows_bastion ? 1 : 0}"
  name                = "windows_bastion_nsg"
  location            = "${var.az_region}"
  resource_group_name = "${var.az_resource_group}"

  security_rule {
    name                       = "RDP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "${local.rdp_port}"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "winrm"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "${local.winrm_port}"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags {
    environment = "windows_bastion"
  }
}

resource "azurerm_public_ip" "pip" {
  count                        = "${var.windows_bastion ? 1 : 0}"
  name                         = "${local.machine_name}-pip"
  location                     = "${var.az_region}"
  resource_group_name          = "${var.az_resource_group}"
  public_ip_address_allocation = "dynamic"
  domain_name_label            = "${lower(local.machine_name)}-${var.az_resource_group}"

  idle_timeout_in_minutes = 30

  tags {
    environment = "Terraform SAP HANA deployment"
  }
}

# Create network interface
resource "azurerm_network_interface" "nic" {
  count                     = "${var.windows_bastion ? 1 : 0}"
  depends_on                = ["azurerm_public_ip.pip"]
  name                      = "${local.machine_name}-nic"
  location                  = "${var.az_region}"
  resource_group_name       = "${var.az_resource_group}"
  network_security_group_id = "${var.windows_bastion ? azurerm_network_security_group.windows_bastion_nsg.id : local.empty_string}"

  ip_configuration {
    name                          = "${local.machine_name}-nic-configuration"
    subnet_id                     = "${var.subnet_id}"
    public_ip_address_id          = "${azurerm_public_ip.pip.id}"
    private_ip_address            = "${var.private_ip_address}"
    private_ip_address_allocation = "${var.private_ip_address != local.empty_string ? local.static : local.dynamic}"
  }

  tags {
    environment = "Terraform SAP HANA deployment"
  }
}

resource "azurerm_virtual_machine" "windows_bastion" {
  name                  = "${local.machine_name}"
  count                 = "${var.windows_bastion ? 1 : 0}"
  location              = "${var.az_region}"
  resource_group_name   = "${var.az_resource_group}"
  network_interface_ids = ["${azurerm_network_interface.nic.id}"]
  vm_size               = "${var.vm_size}"

  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "${local.machine_name}"
    admin_username = "${var.bastion_username}"
    admin_password = "${var.pw_bastion}"
  }

  os_profile_secrets {
    source_vault_id = "${azurerm_key_vault.main.id}"

    vault_certificates {
      certificate_url   = "${azurerm_key_vault_certificate.main.secret_id}"
      certificate_store = "My"
    }
  }

  os_profile_windows_config {
    provision_vm_agent = true

    winrm {
      protocol = "Http"
    }

    winrm {
      protocol        = "Https"
      certificate_url = "${azurerm_key_vault_certificate.main.secret_id}"
    }

    # Auto-Login's required to configure WinRM
    additional_unattend_config {
      pass         = "oobeSystem"
      component    = "Microsoft-Windows-Shell-Setup"
      setting_name = "AutoLogon"
      content      = "<AutoLogon><Password><Value>${var.pw_bastion}</Value></Password><Enabled>true</Enabled><LogonCount>1</LogonCount><Username>${var.bastion_username}</Username></AutoLogon>"
    }

    # Unattend config is to enable basic auth in WinRM, required for the provisioner stage.
    additional_unattend_config {
      pass         = "oobeSystem"
      component    = "Microsoft-Windows-Shell-Setup"
      setting_name = "FirstLogonCommands"
      content      = "${file("${path.module}/files/FirstLogonCommands.xml")}"
    }
  }

  tags {
    win_bastion = ""
  }
}
