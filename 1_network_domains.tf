module "network_domains" {
  source = "terraform-aviatrix-modules/mc-network-domains/aviatrix"

  connection_policies = [
    ["non_pci", "shared"],
    ["pci", "shared"],
    ["control_plane", "non_pci"],
    ["control_plane", "pci"]
  ]

  additional_domains = [
    "control_plane",
    "non_pci",
    "pci",
    "shared"
  ]
}
