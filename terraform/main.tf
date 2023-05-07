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
  name                 = "${var.prefix_name}-vm-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Creación de la subred para el app gateway
resource "azurerm_subnet" "app_gwsubnet" {
  name                 = "${var.prefix_name}-app-gw-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Ip publica para la máquina virtual [Base de datos --> Follow versions Private Link Service 🫰]
resource "azurerm_public_ip" "main" {
  name                = "${var.prefix_name}-vm-public-ip"
  location            = var.region
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
}

# Ip publica para el load balancer ingress controller
resource "azurerm_public_ip" "ingress" {
  name                = "${var.prefix_name}-ingress-public-ip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}
# Since these variables are re-used - a locals block makes this more maintainable
locals {
  backend_address_pool_name      = "${azurerm_virtual_network.main.name}-beap"
  frontend_port_name             = "${azurerm_virtual_network.main.name}-feport"
  frontend_ip_configuration_name = "${azurerm_virtual_network.main.name}-feip"
  http_setting_name              = "${azurerm_virtual_network.main.name}-be-htst"
  listener_name                  = "${azurerm_virtual_network.main.name}-httplstn"
  request_routing_rule_name      = "${azurerm_virtual_network.main.name}-rqrt"
}
# Load balancer para el aks cluster
resource "azurerm_application_gateway" "ingress" {
  name                = "${var.prefix_name}-ingress-lb"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "${var.prefix_name}-appgw-ipconfig"
    subnet_id = azurerm_subnet.app_gwsubnet.id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.ingress.id
  }
  backend_address_pool {
    name = local.backend_address_pool_name
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 20
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  }
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

### -----------------------COMPUTE--------------------- ###
# Creación del clúster de AKS
resource "azurerm_kubernetes_cluster" "main" {
  name                             = "${var.prefix_name}-aks"
  location                         = azurerm_resource_group.main.location
  resource_group_name              = azurerm_resource_group.main.name
  dns_prefix                       = "${var.prefix_name}-aks"
  http_application_routing_enabled = false
  default_node_pool {
    name                = "default"
    node_count          = 1
    vm_size             = "Standard_D2_v2"
    enable_auto_scaling = true
    max_count           = 3
    min_count           = 1
  }
  ingress_application_gateway {
    gateway_id = azurerm_application_gateway.ingress.id
  }

  identity {
    type = "SystemAssigned"
  }

  depends_on = [azurerm_application_gateway.ingress]
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
