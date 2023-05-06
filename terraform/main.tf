### -----------------------MAIN--------------------- ###
# Creación del grupo de recursos
resource "azurerm_resource_group" "main" {
  name     = "${var.prefix_name}-rg"
  location = var.region
}

### -----------------------NETWORK--------------------- ###
# Creación de la red virtual
resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix_name}-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# Creación de la subred para la máquina virtual [CouchDB]
resource "azurerm_subnet" "vm_subnet" {
  name                 = "${var.prefix_name}-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Creación de la subred para el aks cluster
resource "azurerm_subnet" "aks_subnet" {
  name                 = "${var.prefix_name}-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Ip publica para la máquina virtual
resource "azurerm_public_ip" "main" {
  name                = "${var.prefix_name}-public-ip"
  location            = var.region
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
}

### -----------------------SECURITY--------------------- ###
# Creación del grupo de seguridad de red para permitir la comunicación a la vm
resource "azurerm_network_security_group" "vm" {
  name                = "${var.prefix_name}-vm-security-group"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "vm-ssh-rule"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "vm-access-rule"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5984"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# 
resource "azurerm_network_security_group" "aks" {
  name                = "${var.prefix_name}-aks-security-group"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "allow_http"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_ssh"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

### -----------------------COMPUTE--------------------- ###
# Creación del clúster de AKS
resource "azurerm_kubernetes_cluster" "main" {
  name                = "${var.prefix_name}-aks"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${var.prefix_name}-aks"

  default_node_pool {
    name                = "default"
    node_count          = 1
    vm_size             = "Standard_D2_v2"
    os_type             = "Linux"
    enable_auto_scaling = true
    max_count           = 3
    min_count           = 1
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    dns_service_ip = "10.0.2.10"
    service_cidr   = "10.0.2.0/24"
    pod_cidr       = "10.244.0.0/16"
  }

  depends_on = [azurerm_network_security_group.aks]
}

# Recuperación de la configuración de kubectl
data "azurerm_kubernetes_cluster" "main" {
  name                = azurerm_kubernetes_cluster.main.name
  resource_group_name = azurerm_resource_group.main.name
}

# Creación de un archivo local para almacenar la configuración de kubectl
resource "local_sensitive_file" "kubeconfig" {
  content  = data.azurerm_kubernetes_cluster.main.kube_config_raw
  filename = "${path.module}/kubeconfig"
}

# Creando una interfaz de red y una máquina virtual. 
# La interfaz de red se conectará a la red virtual que hemos creado anteriormente y se configurará para obtener una dirección IP dinámica
resource "azurerm_network_interface" "main" {
  name                = "${var.prefix_name}-vm-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "${var.prefix_name}-vm-nic-ipconfig"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
  }
}

# Asociación de la interfaz de red con el grupo de seguridad de red
resource "azurerm_network_interface_security_group_association" "main" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.vm.id
}

# Creación de la máquina virtual para la base de datos CouchDB
resource "azurerm_linux_virtual_machine" "main" {
  name                            = "${var.prefix_name}-vm-couchdb"
  location                        = azurerm_resource_group.main.location
  resource_group_name             = azurerm_resource_group.main.name
  size                            = "Standard_DS2_v2"
  network_interface_ids           = [azurerm_network_interface.main.id]
  disable_password_authentication = false
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  computer_name = "couchDB"
}
