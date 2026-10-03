# Cluster add-ons, installed from their official Helm charts. Bump versions deliberately.

# --- Traefik: ingress controller on the static public IP ---------------------------------
resource "helm_release" "traefik" {
  name             = "traefik"
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  version          = "41.6.1"
  namespace        = "traefik"
  create_namespace = true

  values = [yamlencode({
    service = {
      annotations = {
        # Use the Terraform-managed IP in our resource group instead of a random one.
        "service.beta.kubernetes.io/azure-load-balancer-resource-group" = local.rg
        "service.beta.kubernetes.io/azure-pip-name"                     = azurerm_public_ip.ingress.name
      }
      # Keep real visitor IPs (GoatCounter needs them to count unique visitors).
      spec = { externalTrafficPolicy = "Local" }
    }
    ingressClass = { isDefaultClass = true }
    providers    = { kubernetesIngress = { publishedService = { enabled = true } } }
    resources = {
      requests = { cpu = "50m", memory = "64Mi" }
      limits   = { memory = "256Mi" }
    }
  })]

  depends_on = [azurerm_role_assignment.aks_network]
}

# --- cert-manager: Let's Encrypt certificates (issuers come in Phase 5) -------------------
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.20.0"
  namespace        = "cert-manager"
  create_namespace = true

  values = [yamlencode({
    crds = { enabled = true }
  })]
}

# --- External Secrets Operator: reads Key Vault via workload identity (no secret) ---------
resource "azurerm_user_assigned_identity" "eso" {
  name                = "id-arias-eso"
  location            = local.location
  resource_group_name = local.rg
  tags                = local.tags
}

# Trust tokens issued by this cluster to the ESO service account, and nothing else.
resource "azurerm_federated_identity_credential" "eso" {
  name                      = "aks-external-secrets"
  user_assigned_identity_id = azurerm_user_assigned_identity.eso.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = azurerm_kubernetes_cluster.main.oidc_issuer_url
  subject                   = "system:serviceaccount:external-secrets:external-secrets"
}

resource "azurerm_role_assignment" "eso_kv" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User" # read-only
  principal_id         = azurerm_user_assigned_identity.eso.principal_id
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = "2.10.0"
  namespace        = "external-secrets"
  create_namespace = true

  values = [yamlencode({
    serviceAccount = {
      annotations = {
        "azure.workload.identity/client-id" = azurerm_user_assigned_identity.eso.client_id
        "azure.workload.identity/tenant-id" = data.azurerm_client_config.current.tenant_id
      }
    }
    # Tells AKS's webhook to mount a federated token into the ESO pod.
    podLabels = { "azure.workload.identity/use" = "true" }
  })]

  depends_on = [azurerm_federated_identity_credential.eso, azurerm_role_assignment.eso_kv]
}
