locals {
  atlantis = merge(
    local.helm_defaults,
    {
      name                   = local.helm_dependencies[index(local.helm_dependencies.*.name, "atlantis")].name
      chart                  = local.helm_dependencies[index(local.helm_dependencies.*.name, "atlantis")].name
      repository             = local.helm_dependencies[index(local.helm_dependencies.*.name, "atlantis")].repository
      chart_version          = local.helm_dependencies[index(local.helm_dependencies.*.name, "atlantis")].version
      namespace              = "atlantis"
      create_ns              = false
      enabled                = false
      default_network_policy = true
    },
    var.atlantis
  )

  values_atlantis = <<VALUES
VALUES
}

resource "kubernetes_namespace" "atlantis" {
  count = local.atlantis["enabled"] && local.atlantis["create_ns"] ? 1 : 0

  metadata {
    labels = {
      name                               = local.atlantis["namespace"]
      "${local.labels_prefix}/component" = "atlantis"
    }

    name = local.atlantis["namespace"]
  }
}

resource "helm_release" "atlantis" {
  count                 = local.atlantis["enabled"] ? 1 : 0
  repository            = local.atlantis["repository"]
  name                  = local.atlantis["name"]
  chart                 = local.atlantis["chart"]
  version               = local.atlantis["chart_version"]
  timeout               = local.atlantis["timeout"]
  force_update          = local.atlantis["force_update"]
  recreate_pods         = local.atlantis["recreate_pods"]
  wait                  = local.atlantis["wait"]
  atomic                = local.atlantis["atomic"]
  cleanup_on_fail       = local.atlantis["cleanup_on_fail"]
  dependency_update     = local.atlantis["dependency_update"]
  disable_crd_hooks     = local.atlantis["disable_crd_hooks"]
  disable_webhooks      = local.atlantis["disable_webhooks"]
  render_subchart_notes = local.atlantis["render_subchart_notes"]
  replace               = local.atlantis["replace"]
  reset_values          = local.atlantis["reset_values"]
  reuse_values          = local.atlantis["reuse_values"]
  skip_crds             = local.atlantis["skip_crds"]
  verify                = local.atlantis["verify"]
  values = [
    local.values_atlantis,
    local.atlantis["extra_values"]
  ]
  namespace = local.atlantis["create_ns"] ? kubernetes_namespace.atlantis.*.metadata.0.name[count.index] : local.atlantis["namespace"]

  depends_on = [
    helm_release.kube-prometheus-stack
  ]
}

resource "kubernetes_network_policy" "atlantis_default_deny" {
  count = local.atlantis["create_ns"] && local.atlantis["enabled"] && local.atlantis["default_network_policy"] ? 1 : 0

  metadata {
    name      = "${kubernetes_namespace.atlantis.*.metadata.0.name[count.index]}-default-deny"
    namespace = kubernetes_namespace.atlantis.*.metadata.0.name[count.index]
  }

  spec {
    pod_selector {
    }
    policy_types = ["Ingress"]
  }
}

resource "kubernetes_network_policy" "atlantis_allow_namespace" {
  count = local.atlantis["create_ns"] && local.atlantis["enabled"] && local.atlantis["default_network_policy"] ? 1 : 0

  metadata {
    name      = "${kubernetes_namespace.atlantis.*.metadata.0.name[count.index]}-allow-namespace"
    namespace = kubernetes_namespace.atlantis.*.metadata.0.name[count.index]
  }

  spec {
    pod_selector {
    }

    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = kubernetes_namespace.atlantis.*.metadata.0.name[count.index]
          }
        }
      }
    }

    policy_types = ["Ingress"]
  }
}

