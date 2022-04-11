locals {
  tekton-pipeline = merge(
    local.helm_defaults,
    {
      name                   = local.helm_dependencies[index(local.helm_dependencies.*.name, "tekton-pipeline")].name
      chart                  = local.helm_dependencies[index(local.helm_dependencies.*.name, "tekton-pipeline")].name
      repository             = local.helm_dependencies[index(local.helm_dependencies.*.name, "tekton-pipeline")].repository
      chart_version          = local.helm_dependencies[index(local.helm_dependencies.*.name, "tekton-pipeline")].version
      create_ns              = false
      namespace              = "tekton-pipeline"
      enabled                = false
      default_network_policy = true
    },
    var.tekton-pipeline
  )

  values_tekton-pipeline = <<VALUES
VALUES

}

resource "kubernetes_namespace" "tekton-pipeline" {
  count = local.tekton-pipeline["enabled"] && local.tekton-pipeline["create_ns"] ? 1 : 0

  metadata {
    labels = {
      name                               = local.tekton-pipeline["namespace"]
      "${local.labels_prefix}/component" = "tekton-pipeline"
    }

    name = local.tekton-pipeline["namespace"]
  }
}

resource "helm_release" "tekton-pipeline" {
  count                 = local.tekton-pipeline["enabled"] ? 1 : 0
  repository            = local.tekton-pipeline["repository"]
  name                  = local.tekton-pipeline["name"]
  chart                 = local.tekton-pipeline["chart"]
  version               = local.tekton-pipeline["chart_version"]
  timeout               = local.tekton-pipeline["timeout"]
  force_update          = local.tekton-pipeline["force_update"]
  recreate_pods         = local.tekton-pipeline["recreate_pods"]
  wait                  = local.tekton-pipeline["wait"]
  atomic                = local.tekton-pipeline["atomic"]
  cleanup_on_fail       = local.tekton-pipeline["cleanup_on_fail"]
  dependency_update     = local.tekton-pipeline["dependency_update"]
  disable_crd_hooks     = local.tekton-pipeline["disable_crd_hooks"]
  disable_webhooks      = local.tekton-pipeline["disable_webhooks"]
  render_subchart_notes = local.tekton-pipeline["render_subchart_notes"]
  replace               = local.tekton-pipeline["replace"]
  reset_values          = local.tekton-pipeline["reset_values"]
  reuse_values          = local.tekton-pipeline["reuse_values"]
  skip_crds             = local.tekton-pipeline["skip_crds"]
  verify                = local.tekton-pipeline["verify"]
  values = [
    local.values_tekton-pipeline,
    local.tekton-pipeline["extra_values"]
  ]
  namespace = local.tekton-pipeline["create_ns"] ? kubernetes_namespace.tekton-pipeline.*.metadata.0.name[count.index] : local.tekton-pipeline["namespace"]

  depends_on = [
    helm_release.kube-prometheus-stack
  ]
}

resource "kubernetes_network_policy" "tekton-pipeline_default_deny" {
  count = local.tekton-pipeline["create_ns"] && local.tekton-pipeline["enabled"] && local.tekton-pipeline["default_network_policy"] ? 1 : 0

  metadata {
    name      = "${kubernetes_namespace.tekton-pipeline.*.metadata.0.name[count.index]}-default-deny"
    namespace = kubernetes_namespace.tekton-pipeline.*.metadata.0.name[count.index]
  }

  spec {
    pod_selector {
    }
    policy_types = ["Ingress"]
  }
}

resource "kubernetes_network_policy" "tekton-pipeline_allow_namespace" {
  count = local.tekton-pipeline["create_ns"] && local.tekton-pipeline["enabled"] && local.tekton-pipeline["default_network_policy"] ? 1 : 0

  metadata {
    name      = "${kubernetes_namespace.tekton-pipeline.*.metadata.0.name[count.index]}-allow-namespace"
    namespace = kubernetes_namespace.tekton-pipeline.*.metadata.0.name[count.index]
  }

  spec {
    pod_selector {
    }

    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = kubernetes_namespace.tekton-pipeline.*.metadata.0.name[count.index]
          }
        }
      }
    }

    policy_types = ["Ingress"]
  }
}

resource "kubernetes_network_policy" "tekton-pipeline_allow_ingress" {
  count = local.tekton-pipeline["enabled"] && local.tekton-pipeline["default_network_policy"] ? 1 : 0

  metadata {
    name      = "${local.tekton-pipeline["create_ns"] ? kubernetes_namespace.tekton-pipeline.*.metadata.0.name[count.index] : local.tekton-pipeline["namespace"]}-allow-ingress-tekton-pipeline"
    namespace = local.tekton-pipeline["create_ns"] ? kubernetes_namespace.tekton-pipeline.*.metadata.0.name[count.index] : local.tekton-pipeline["namespace"]
  }

  spec {
    pod_selector {
    }

    ingress {
      from {
        namespace_selector {
          match_labels = {
            "${local.labels_prefix}/component" = "ingress"
          }
        }
      }
    }

    policy_types = ["Ingress"]
  }
}