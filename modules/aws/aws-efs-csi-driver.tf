locals {
  aws-efs-csi-driver = merge(
    local.helm_defaults,
    {
      name          = local.helm_dependencies[index(local.helm_dependencies.*.name, "aws-efs-csi-driver")].name
      chart         = local.helm_dependencies[index(local.helm_dependencies.*.name, "aws-efs-csi-driver")].name
      repository    = local.helm_dependencies[index(local.helm_dependencies.*.name, "aws-efs-csi-driver")].repository
      chart_version = local.helm_dependencies[index(local.helm_dependencies.*.name, "aws-efs-csi-driver")].version
      namespace     = "kube-system"
      create_ns     = false
      service_account_names = {
        controller = "efs-csi-controller-sa"
        node       = "efs-csi-node-sa"
      }
      create_iam_resources_irsa                      = true
      create_storage_class                           = true
      storage_class_name                             = "efs-sc"
      is_default_class                               = false
      enabled                                        = false
      iam_policy_override                            = null
      sg_vpc_ingress_cidrs                           = ["0.0.0.0/0"]
      sg_vpc_id                                      = null
      sg_ingress_cidr_blocks                         = null
      sg_egress_ipv6_cidr_blocks                     = null
      sg_auto_ingress_with_self                      = []
      sg_input_ingress_with_source_security_group_id = []
      name_prefix                                    = "${var.cluster-name}-aws-efs-csi-driver"
    },
    var.aws-efs-csi-driver
  )

  values_aws-efs-csi-driver = <<-VALUES
    controller:
      serviceAccount:
        annotations:
          eks.amazonaws.com/role-arn: "${local.aws-efs-csi-driver["enabled"] && local.aws-efs-csi-driver["create_iam_resources_irsa"] ? module.iam_assumable_role_aws-efs-csi-driver.iam_role_arn : ""}"
    VALUES

}

module "iam_assumable_role_aws-efs-csi-driver" {
  source                     = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                    = "~> 4.0"
  create_role                = local.aws-efs-csi-driver["enabled"] && local.aws-efs-csi-driver["create_iam_resources_irsa"]
  role_name                  = local.aws-efs-csi-driver["name_prefix"]
  provider_url               = replace(var.eks["cluster_oidc_issuer_url"], "https://", "")
  role_policy_arns           = local.aws-efs-csi-driver["enabled"] && local.aws-efs-csi-driver["create_iam_resources_irsa"] ? [aws_iam_policy.aws-efs-csi-driver[0].arn] : []
  number_of_role_policy_arns = 1
  oidc_fully_qualified_subjects = [
    "system:serviceaccount:${local.aws-efs-csi-driver["namespace"]}:${local.aws-efs-csi-driver["service_account_names"]["controller"]}",
  ]
  tags = local.tags
}

data "aws_iam_policy_document" "aws-efs-csi-driver" {
  count = local.aws-efs-csi-driver.enabled && local.aws-efs-csi-driver.create_iam_resources_irsa ? 1 : 0
  source_policy_documents = [
    data.aws_iam_policy_document.aws-efs-csi-driver_default.0.json
  ]
}

data "aws_iam_policy_document" "aws-efs-csi-driver_default" {
  count       = local.aws-efs-csi-driver.enabled && local.aws-efs-csi-driver.create_iam_resources_irsa ? 1 : 0
  source_json = templatefile("${path.module}/iam/aws-efs-csi-driver.json", { arn-partition = var.arn-partition })
}

resource "aws_iam_policy" "aws-efs-csi-driver" {
  count  = local.aws-efs-csi-driver["enabled"] && local.aws-efs-csi-driver["create_iam_resources_irsa"] ? 1 : 0
  name   = local.aws-efs-csi-driver["name_prefix"]
  policy = local.aws-efs-csi-driver["iam_policy_override"] == null ? data.aws_iam_policy_document.aws-efs-csi-driver.0.json : local.aws-efs-csi-driver["iam_policy_override"]
  tags   = local.tags
}

resource "kubernetes_namespace" "aws-efs-csi-driver" {
  count = local.aws-efs-csi-driver["enabled"] && local.aws-efs-csi-driver["create_ns"] ? 1 : 0

  metadata {
    labels = {
      name = local.aws-efs-csi-driver["namespace"]
    }

    name = local.aws-efs-csi-driver["namespace"]
  }
}

resource "aws_efs_file_system" "aws-efs-csi-driver" {
  count                           = local.aws-efs-csi-driver["enabled"] && lookup(local.aws-efs-csi-driver, "file_system_id", null) == null ? 1 : 0
  creation_token                  = local.aws-efs-csi-driver["name_prefix"]
  encrypted                       = lookup(local.aws-efs-csi-driver, "encrypted", "true")
  performance_mode                = lookup(local.aws-efs-csi-driver, "performance_mode", "generalPurpose")
  provisioned_throughput_in_mibps = lookup(local.aws-efs-csi-driver, "provisioned_throughput_in_mibps", 0)
  throughput_mode                 = lookup(local.aws-efs-csi-driver, "provisioned_throughput_in_mibps", 0) == 0 ? "bursting" : "provisioned"
  dynamic "lifecycle_policy" {
    for_each = lookup(local.aws-efs-csi-driver, "lifecycle_policy", [])
    content {
      transition_to_ia = lookup(lifecycle_policy.value, "transition_to_ia", null)
    }
  }
  tags = merge(local.tags, { "Name" : local.aws-efs-csi-driver["name_prefix"] })
}

resource "aws_efs_mount_target" "aws-efs-csi-driver" {
  count           = local.aws-efs-csi-driver["enabled"] ? length(local.aws-efs-csi-driver["subnets"]) : 0
  file_system_id  = lookup(local.aws-efs-csi-driver, "file_system_id", null) == null ? aws_efs_file_system.aws-efs-csi-driver.0.id : local.aws-efs-csi-driver["file_system_id"]
  subnet_id       = element(local.aws-efs-csi-driver["subnets"], count.index)
  security_groups = [module.security-group-efs-csi-driver.0.security_group_id]
}

module "security-group-efs-csi-driver" {
  count                                 = local.aws-efs-csi-driver["enabled"] ? 1 : 0
  source                                = "terraform-aws-modules/security-group/aws//modules/nfs"
  version                               = "~> 4.0"
  name                                  = local.aws-efs-csi-driver["name_prefix"]
  description                           = "NFS access to ${local.aws-efs-csi-driver["name_prefix"]}"
  vpc_id                                = local.aws-efs-csi-driver["sg_vpc_id"]
  ingress_cidr_blocks                   = local.aws-efs-csi-driver["sg_vpc_ingress_cidrs"]
  egress_ipv6_cidr_blocks               = local.aws-efs-csi-driver["sg_egress_ipv6_cidr_blocks"]
  auto_ingress_with_self                = local.aws-efs-csi-driver["sg_auto_ingress_with_self"]
  ingress_with_source_security_group_id = local.aws-efs-csi-driver["sg_input_ingress_with_source_security_group_id"]
  tags                                  = local.tags
}

resource "helm_release" "aws-efs-csi-driver" {
  count                 = local.aws-efs-csi-driver["enabled"] ? 1 : 0
  repository            = local.aws-efs-csi-driver["repository"]
  name                  = local.aws-efs-csi-driver["name"]
  chart                 = local.aws-efs-csi-driver["chart"]
  version               = local.aws-efs-csi-driver["chart_version"]
  timeout               = local.aws-efs-csi-driver["timeout"]
  force_update          = local.aws-efs-csi-driver["force_update"]
  recreate_pods         = local.aws-efs-csi-driver["recreate_pods"]
  wait                  = local.aws-efs-csi-driver["wait"]
  atomic                = local.aws-efs-csi-driver["atomic"]
  cleanup_on_fail       = local.aws-efs-csi-driver["cleanup_on_fail"]
  dependency_update     = local.aws-efs-csi-driver["dependency_update"]
  disable_crd_hooks     = local.aws-efs-csi-driver["disable_crd_hooks"]
  disable_webhooks      = local.aws-efs-csi-driver["disable_webhooks"]
  render_subchart_notes = local.aws-efs-csi-driver["render_subchart_notes"]
  replace               = local.aws-efs-csi-driver["replace"]
  reset_values          = local.aws-efs-csi-driver["reset_values"]
  reuse_values          = local.aws-efs-csi-driver["reuse_values"]
  skip_crds             = local.aws-efs-csi-driver["skip_crds"]
  verify                = local.aws-efs-csi-driver["verify"]
  values = [
    local.values_aws-efs-csi-driver,
    local.aws-efs-csi-driver["extra_values"]
  ]
  namespace = local.aws-efs-csi-driver["create_ns"] ? kubernetes_namespace.aws-efs-csi-driver.*.metadata.0.name[count.index] : local.aws-efs-csi-driver["namespace"]
}