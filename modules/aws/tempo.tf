locals {
  tempo = merge(
    local.helm_defaults,
    {
      name                      = local.helm_dependencies[index(local.helm_dependencies.*.name, "tempo")].name
      chart                     = local.helm_dependencies[index(local.helm_dependencies.*.name, "tempo")].name
      repository                = local.helm_dependencies[index(local.helm_dependencies.*.name, "tempo")].repository
      chart_version             = local.helm_dependencies[index(local.helm_dependencies.*.name, "tempo")].version
      namespace                 = "monitoring"
      create_iam_resources_irsa = true
      iam_policy_override       = null
      create_ns                 = false
      enabled                   = false
      default_network_policy    = true
      create_bucket             = false
      bucket                    = "tempo-store-${var.cluster-name}"
      bucket_force_destroy      = false
      name_prefix               = "${var.cluster-name}-tempo"
    },
    var.tempo
  )

  values_tempo = <<-VALUES
    serviceAccount:
      name: ${local.tempo["name"]}
      annotations:
        eks.amazonaws.com/role-arn: "${local.tempo["enabled"] && local.tempo["create_iam_resources_irsa"] ? module.iam_assumable_role_tempo.iam_role_arn : ""}"  
    overrides: 
      storage:
        trace: 
          backend: s3
          s3:
            bucket: ${local.tempo["bucket"]}
            region: ${data.aws_region.current.name}
            endpoint: s3.${data.aws_region.current.name}.amazonaws.com
            sse_config:
              type: "SSE-S3"
    VALUES
}

module "iam_assumable_role_tempo" {
  source                       = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                      = "~> 4.0"
  create_role                  = local.tempo["enabled"] && local.tempo["create_iam_resources_irsa"]
  role_name                    = local.tempo["name_prefix"]
  provider_url                 = replace(var.eks["cluster_oidc_issuer_url"], "https://", "")
  role_policy_arns             = local.tempo["enabled"] && local.tempo["create_iam_resources_irsa"] ? [aws_iam_policy.tempo[0].arn] : []
  number_of_role_policy_arns   = 1
  oidc_subjects_with_wildcards = ["system:serviceaccount:${local.tempo["namespace"]}:${local.tempo["name"]}-*"]
  tags                         = local.tags
}


resource "aws_iam_policy" "tempo" {
  count  = local.tempo["enabled"] && local.tempo["create_iam_resources_irsa"] ? 1 : 0
  name   = local.tempo["name_prefix"]
  policy = local.tempo["iam_policy_override"] == null ? data.aws_iam_policy_document.tempo.json : local.tempo["iam_policy_override"]
  tags   = local.tags
}


data "aws_iam_policy_document" "tempo" {
  statement {
    effect = "Allow"

    actions = [
      "s3:ListBucket"
    ]

    resources = ["arn:${var.arn-partition}:s3:::${local.tempo["bucket"]}"]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:*Object"
    ]

    resources = ["arn:${var.arn-partition}:s3:::${local.tempo["bucket"]}/*"]
  }
}

module "tempo_bucket" {
  create_bucket = local.tempo["enabled"] && local.tempo["create_bucket"]

  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true

  force_destroy = local.tempo["bucket_force_destroy"]

  bucket = local.tempo["bucket"]
  acl    = "private"

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }
  tags = local.tags
}

resource "kubernetes_namespace" "tempo" {
  count = local.tempo["enabled"] && local.tempo["create_ns"] ? 1 : 0

  metadata {
    labels = {
      name                               = local.tempo["namespace"]
      "${local.labels_prefix}/component" = "monitoring"
    }

    name = local.tempo["namespace"]
  }
}

resource "helm_release" "tempo" {
  count                 = local.tempo["enabled"] ? 1 : 0
  repository            = local.tempo["repository"]
  name                  = local.tempo["name"]
  chart                 = local.tempo["chart"]
  version               = local.tempo["chart_version"]
  timeout               = local.tempo["timeout"]
  force_update          = local.tempo["force_update"]
  recreate_pods         = local.tempo["recreate_pods"]
  wait                  = local.tempo["wait"]
  atomic                = local.tempo["atomic"]
  cleanup_on_fail       = local.tempo["cleanup_on_fail"]
  dependency_update     = local.tempo["dependency_update"]
  disable_crd_hooks     = local.tempo["disable_crd_hooks"]
  disable_webhooks      = local.tempo["disable_webhooks"]
  render_subchart_notes = local.tempo["render_subchart_notes"]
  replace               = local.tempo["replace"]
  reset_values          = local.tempo["reset_values"]
  reuse_values          = local.tempo["reuse_values"]
  skip_crds             = local.tempo["skip_crds"]
  verify                = local.tempo["verify"]
  values = [
    local.values_tempo,
    local.tempo["extra_values"]
  ]
  namespace = local.tempo["create_ns"] ? kubernetes_namespace.tempo.*.metadata.0.name[count.index] : local.tempo["namespace"]

  depends_on = [
    helm_release.kube-prometheus-stack
  ]
}
