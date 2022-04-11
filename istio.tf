locals {
  istio-base = merge(
    local.helm_defaults,
    {
      name                   = local.helm_dependencies[index(local.helm_dependencies.*.name, "istio-base")].name
      chart                  = local.helm_dependencies[index(local.helm_dependencies.*.name, "istio-base")].name
      repository             = local.helm_dependencies[index(local.helm_dependencies.*.name, "istio-base")].repository
      chart_version          = local.helm_dependencies[index(local.helm_dependencies.*.name, "istio-base")].version
      namespace              = "istio-system"
      create_ns              = false
      enabled                = false
      default_network_policy = true
    },
    var.istio-base
  )
  values_istio-base = <<VALUES
    VALUES

  istiod = merge(
    local.helm_defaults,
    {
      name                   = local.helm_dependencies[index(local.helm_dependencies.*.name, "istiod")].name
      chart                  = local.helm_dependencies[index(local.helm_dependencies.*.name, "istiod")].name
      repository             = local.helm_dependencies[index(local.helm_dependencies.*.name, "istiod")].repository
      chart_version          = local.helm_dependencies[index(local.helm_dependencies.*.name, "istiod")].version
      namespace              = "istio-system"
      create_ns              = false
      enabled                = false
      default_network_policy = true
    },
    var.istiod
  )
  values_istiod = <<VALUES
    VALUES

  istio-ingress = merge(
    local.helm_defaults,
    {
      name                   = local.helm_dependencies[index(local.helm_dependencies.*.name, "istio-ingress")].name
      chart                  = local.helm_dependencies[index(local.helm_dependencies.*.name, "istio-ingress")].name
      repository             = local.helm_dependencies[index(local.helm_dependencies.*.name, "istio-ingress")].repository
      chart_version          = local.helm_dependencies[index(local.helm_dependencies.*.name, "istio-ingress")].version
      namespace              = "istio-system"
      create_ns              = false
      enabled                = false
      default_network_policy = true
    },
    var.istio-ingress
  )
  values_istio-ingress = <<VALUES
    VALUES

  istio-egress = merge(
    local.helm_defaults,
    {
      name                   = local.helm_dependencies[index(local.helm_dependencies.*.name, "istio-egress")].name
      chart                  = local.helm_dependencies[index(local.helm_dependencies.*.name, "istio-egress")].name
      repository             = local.helm_dependencies[index(local.helm_dependencies.*.name, "istio-egress")].repository
      chart_version          = local.helm_dependencies[index(local.helm_dependencies.*.name, "istio-egress")].version
      namespace              = "istio-system"
      create_ns              = false
      enabled                = false
      default_network_policy = true
    },
    var.istio-egress
  )
  values_istio-egress = <<VALUES
    VALUES
}

resource "kubernetes_namespace" "istio-system" {
  count = local.istio-base["enabled"] && local.istio-base["create_ns"] ? 1 : 0

  metadata {
    labels = {
      name                               = local.istio-base["namespace"]
      "${local.labels_prefix}/component" = "istio"
    }

    name = local.istio-base["namespace"]
  }
}

resource "helm_release" "istio-base" {
  count                 = local.istio-base["enabled"] ? 1 : 0
  repository            = local.istio-base["repository"]
  name                  = local.istio-base["name"]
  chart                 = local.istio-base["chart"]
  version               = local.istio-base["chart_version"]
  timeout               = local.istio-base["timeout"]
  force_update          = local.istio-base["force_update"]
  recreate_pods         = local.istio-base["recreate_pods"]
  wait                  = local.istio-base["wait"]
  atomic                = local.istio-base["atomic"]
  cleanup_on_fail       = local.istio-base["cleanup_on_fail"]
  dependency_update     = local.istio-base["dependency_update"]
  disable_crd_hooks     = local.istio-base["disable_crd_hooks"]
  disable_webhooks      = local.istio-base["disable_webhooks"]
  render_subchart_notes = local.istio-base["render_subchart_notes"]
  replace               = local.istio-base["replace"]
  reset_values          = local.istio-base["reset_values"]
  reuse_values          = local.istio-base["reuse_values"]
  skip_crds             = local.istio-base["skip_crds"]
  verify                = local.istio-base["verify"]
  values = [
    local.values_istio-base,
    local.istio-base["extra_values"]
  ]
  namespace = local.istio-base["create_ns"] ? kubernetes_namespace.istio-system.*.metadata.0.name[count.index] : local.istio-base["namespace"]

  depends_on = [
    kubernetes_namespace.istio-system
  ]
}

resource "helm_release" "istiod" {
  count                 = local.istiod["enabled"] && !local.istiod["skip_crds"] ? 1 : 0
  repository            = local.istiod["repository"]
  name                  = local.istiod["name"]
  chart                 = local.istiod["chart"]
  version               = local.istiod["chart_version"]
  timeout               = local.istiod["timeout"]
  force_update          = local.istiod["force_update"]
  recreate_pods         = local.istiod["recreate_pods"]
  wait                  = local.istiod["wait"]
  atomic                = local.istiod["atomic"]
  cleanup_on_fail       = local.istiod["cleanup_on_fail"]
  dependency_update     = local.istiod["dependency_update"]
  disable_crd_hooks     = local.istiod["disable_crd_hooks"]
  disable_webhooks      = local.istiod["disable_webhooks"]
  render_subchart_notes = local.istiod["render_subchart_notes"]
  replace               = local.istiod["replace"]
  reset_values          = local.istiod["reset_values"]
  reuse_values          = local.istiod["reuse_values"]
  skip_crds             = local.istiod["skip_crds"]
  verify                = local.istiod["verify"]
  values = [
    local.values_istiod,
    local.istiod["extra_values"]
  ]

  depends_on = [
    kubernetes_namespace.istio-system,
    helm_release.istio-base
  ]
}

resource "helm_release" "istio-ingress" {
  count                 = local.istio-ingress["enabled"] && !local.istiod["skip_crds"] ? 1 : 0
  repository            = local.istio-ingress["repository"]
  name                  = local.istio-ingress["name"]
  chart                 = local.istio-ingress["chart"]
  version               = local.istio-ingress["chart_version"]
  timeout               = local.istio-ingress["timeout"]
  force_update          = local.istio-ingress["force_update"]
  recreate_pods         = local.istio-ingress["recreate_pods"]
  wait                  = local.istio-ingress["wait"]
  atomic                = local.istio-ingress["atomic"]
  cleanup_on_fail       = local.istio-ingress["cleanup_on_fail"]
  dependency_update     = local.istio-ingress["dependency_update"]
  disable_crd_hooks     = local.istio-ingress["disable_crd_hooks"]
  disable_webhooks      = local.istio-ingress["disable_webhooks"]
  render_subchart_notes = local.istio-ingress["render_subchart_notes"]
  replace               = local.istio-ingress["replace"]
  reset_values          = local.istio-ingress["reset_values"]
  reuse_values          = local.istio-ingress["reuse_values"]
  skip_crds             = local.istio-ingress["skip_crds"]
  verify                = local.istio-ingress["verify"]
  values = [
    local.values_istio-ingress,
    local.istio-ingress["extra_values"]
  ]
  depends_on = [
    kubernetes_namespace.istio-system,
    helm_release.istio-base
  ]
}

resource "helm_release" "istio-egress" {
  count                 = local.istio-egress["enabled"] && !local.istiod["skip_crds"] ? 1 : 0
  repository            = local.istio-egress["repository"]
  name                  = local.istio-egress["name"]
  chart                 = local.istio-egress["chart"]
  version               = local.istio-egress["chart_version"]
  timeout               = local.istio-egress["timeout"]
  force_update          = local.istio-egress["force_update"]
  recreate_pods         = local.istio-egress["recreate_pods"]
  wait                  = local.istio-egress["wait"]
  atomic                = local.istio-egress["atomic"]
  cleanup_on_fail       = local.istio-egress["cleanup_on_fail"]
  dependency_update     = local.istio-egress["dependency_update"]
  disable_crd_hooks     = local.istio-egress["disable_crd_hooks"]
  disable_webhooks      = local.istio-egress["disable_webhooks"]
  render_subchart_notes = local.istio-egress["render_subchart_notes"]
  replace               = local.istio-egress["replace"]
  reset_values          = local.istio-egress["reset_values"]
  reuse_values          = local.istio-egress["reuse_values"]
  skip_crds             = local.istio-egress["skip_crds"]
  verify                = local.istio-egress["verify"]
  values = [
    local.values_istio-egress,
    local.istio-egress["extra_values"]
  ]
  depends_on = [
    kubernetes_namespace.istio-system,
    helm_release.istio-base
  ]
}

resource "kubernetes_network_policy" "istio-base_default_deny" {
  count = local.istio-base["create_ns"] && local.istio-base["enabled"] && local.istio-base["default_network_policy"] ? 1 : 0

  metadata {
    name      = "${kubernetes_namespace.istio-system.*.metadata.0.name[count.index]}-default-deny"
    namespace = kubernetes_namespace.istio-system.*.metadata.0.name[count.index]
  }

  spec {
    pod_selector {
    }
    policy_types = ["Ingress"]
  }
}

resource "kubernetes_network_policy" "istio-base_allow_namespace" {
  count = local.istio-base["create_ns"] && local.istio-base["enabled"] && local.istio-base["default_network_policy"] ? 1 : 0

  metadata {
    name      = "${kubernetes_namespace.istio-system.*.metadata.0.name[count.index]}-allow-namespace"
    namespace = kubernetes_namespace.istio-system.*.metadata.0.name[count.index]
  }

  spec {
    pod_selector {
    }

    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = kubernetes_namespace.istio-system.*.metadata.0.name[count.index]
          }
        }
      }
    }

    policy_types = ["Ingress"]
  }
}

resource "kubernetes_network_policy" "istiod_allow_namespace" {
  count = local.istio-base["create_ns"] && local.istiod["enabled"] && local.istiod["default_network_policy"] ? 1 : 0

  metadata {
    name      = "${kubernetes_namespace.istio-system.*.metadata.0.name[count.index]}-allow-namespace"
    namespace = kubernetes_namespace.istio-system.*.metadata.0.name[count.index]
  }

  spec {
    pod_selector {
    }

    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = kubernetes_namespace.istio-system.*.metadata.0.name[count.index]
          }
        }
      }
    }

    policy_types = ["Ingress"]
  }
}

resource "kubernetes_network_policy" "istio-ingress_allow_namespace" {
  count = local.istio-base["create_ns"] && local.istio-ingress["enabled"] && local.istio-ingress["default_network_policy"] ? 1 : 0

  metadata {
    name      = "${kubernetes_namespace.istio-system.*.metadata.0.name[count.index]}-allow-namespace"
    namespace = kubernetes_namespace.istio-system.*.metadata.0.name[count.index]
  }

  spec {
    pod_selector {
    }

    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = kubernetes_namespace.istio-system.*.metadata.0.name[count.index]
          }
        }
      }
    }

    policy_types = ["Ingress"]
  }
}

resource "kubernetes_network_policy" "istio-egress_allow_namespace" {
  count = local.istio-base["create_ns"] && local.istio-egress["enabled"] && local.istio-egress["default_network_policy"] ? 1 : 0

  metadata {
    name      = "${kubernetes_namespace.istio-system.*.metadata.0.name[count.index]}-allow-namespace"
    namespace = kubernetes_namespace.istio-system.*.metadata.0.name[count.index]
  }

  spec {
    pod_selector {
    }

    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = kubernetes_namespace.istio-system.*.metadata.0.name[count.index]
          }
        }
      }
    }

    policy_types = ["Egress"]
  }
}