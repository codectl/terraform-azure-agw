module "naming" {
  source  = "codectl/naming/azure"
  version = "~> 0.1"

  suffix = ["demo", "dev"]
}

module "regions" {
  source  = "codectl/locations/azure"
  version = "~> 1.0"

  location = {
    primary = "westeurope"
  }
}

module "rg" {
  source  = "codectl/rg/azure"
  version = "~> 1.0"

  groups = {
    demo = {
      name     = module.naming.resource_group.name_unique
      location = module.regions.location.primary.name
    }
  }
}

module "network" {
  source  = "codectl/vnet/azure"
  version = "~> 1.0"


  vnet = {
    name                = module.naming.virtual_network.name
    address_space       = ["10.18.0.0/16"]
    location            = module.rg.groups.demo.location
    resource_group_name = module.rg.groups.demo.name

    subnets = {
      gw = {
        address_prefixes = ["10.18.1.0/24"]
        network_security_group = {
          rules = local.rules
        }
      }
    }
  }
}

module "kv" {
  source  = "codectl/kv/azure"
  version = "~> 1.0"

  vault = {
    name                = module.naming.key_vault.name_unique
    location            = module.rg.groups.demo.location
    resource_group_name = module.rg.groups.demo.name
    certs               = local.certs
  }
}

module "public_ip" {
  source  = "codectl/pip/azure"
  version = "~> 1.0"

  public_ips = {
    fe = {
      name                = module.naming.public_ip.name
      location            = module.rg.groups.demo.location
      resource_group_name = module.rg.groups.demo.name

      zones = ["1", "2", "3"]
    }
  }
}

module "uai" {
  source  = "codectl/uai/azure"
  version = "~> 1.0"

  identity = {
    name                = module.naming.user_assigned_identity.name
    location            = module.rg.groups.demo.location
    resource_group_name = module.rg.groups.demo.name
  }
}

module "application_gateway" {
  source  = "codectl/agw/azure"
  version = "~> 1.0"

  application_gateway = {
    name                = module.naming.application_gateway.name
    resource_group_name = module.rg.groups.demo.name
    location            = module.rg.groups.demo.location

    sku = {
      name     = "Standard_v2"
      tier     = "Standard_v2"
      capacity = 2
    }

    identity = {
      type         = "UserAssigned"
      identity_ids = [module.uai.identity.id]
    }

    role_assignments = {
      kv = {
        scope        = module.kv.vault.id
        principal_id = module.uai.identity.principal_id
      }
    }

    gateway_ip_configurations = {
      main = {
        name      = "gateway-ip-configuration"
        subnet_id = module.network.subnets.gw.id
      }
    }

    frontend_ip_configurations = {
      public = {
        name                 = "feip-prod-westus-001"
        public_ip_address_id = module.public_ip.public_ips.fe.id
      }
    }

    frontend_ports = {
      https = {
        name = "fep-prod-westus-001"
        port = 443
      }
    }

    applications = {
      api = local.api
    }
  }
}
