# ---------------------------------------------------------------------------------------------------------------------
# Observability Module
# Prometheus + Grafana via Helm, CloudWatch, PagerDuty, custom alarms.
# ---------------------------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------------------------
# CloudWatch Container Insights
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_eks_addon" "container_insights" {
  count = var.enable_cloudwatch_insights ? 1 : 0

  cluster_name  = var.eks_cluster_name
  addon_name    = "amazon-cloudwatch-observability"
  addon_version = "v1.2.0-eksbuild.1"

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-container-insights"
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# CloudWatch Log Groups
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/eks/${var.eks_cluster_name}/application"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-app-logs"
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# CloudWatch Alarms
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.name_prefix}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU utilization exceeds 80%"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    AutoScalingGroupName = var.eks_cluster_name
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-high-cpu"
  })
}

resource "aws_cloudwatch_metric_alarm" "high_latency" {
  alarm_name          = "${var.name_prefix}-high-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 2
  alarm_description   = "ALB latency exceeds 2 seconds"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-high-latency"
  })
}

resource "aws_cloudwatch_metric_alarm" "five_xx_errors" {
  alarm_name          = "${var.name_prefix}-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "5XX errors exceed threshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-5xx-errors"
  })
}

resource "aws_cloudwatch_metric_alarm" "failed_logins" {
  alarm_name          = "${var.name_prefix}-failed-logins"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FailedLoginAttempts"
  namespace           = "Custom/Security"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Failed login attempts exceed threshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-failed-logins"
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# SNS Topic for Alerts
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_sns_topic" "alerts" {
  name = "${var.name_prefix}-alerts"

  kms_master_key_id = var.kms_key_arn

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-alerts"
  })
}

resource "aws_sns_topic_subscription" "email" {
  count = var.alert_email != null ? 1 : 0

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ---------------------------------------------------------------------------------------------------------------------
# PagerDuty Service Integration
# ---------------------------------------------------------------------------------------------------------------------

resource "pagerduty_service" "main" {
  count = var.pagerduty_service_name != null ? 1 : 0

  name                    = var.pagerduty_service_name
  escalation_policy       = pagerduty_escalation_policy.main[0].id
  alert_creation          = "create_alerts_and_incidents"
  auto_resolve_timeout    = 14400
  acknowledgement_timeout = 1800

  incident_urgency_rule {
    type    = "constant"
    urgency = "high"
  }
}

resource "pagerduty_escalation_policy" "main" {
  count = var.pagerduty_service_name != null ? 1 : 0

  name      = "${var.name_prefix}-escalation"
  num_loops = 2

  rule {
    escalation_delay_in_minutes = 15
    target {
      type = "user_reference"
      id   = pagerduty_user.placeholder[0].id
    }
  }
}

resource "pagerduty_user" "placeholder" {
  count = var.pagerduty_service_name != null ? 1 : 0

  name  = "${var.name_prefix}-oncall"
  email = coalesce(var.alert_email, "oncall@placeholder.com")
  role  = "limited_user"
}

resource "pagerduty_service_integration" "cloudwatch" {
  count = var.pagerduty_service_name != null ? 1 : 0

  name    = "CloudWatch Integration"
  service = pagerduty_service.main[0].id
  type    = "events_api_v2_inbound_integration"
}

# ---------------------------------------------------------------------------------------------------------------------
# Kubernetes / Helm Resources (Prometheus + Grafana)
# ---------------------------------------------------------------------------------------------------------------------

# These require the kubernetes and helm providers configured in root.
# They are conditionally created based on enable_prometheus / enable_grafana.

resource "kubernetes_namespace" "monitoring" {
  count = var.enable_prometheus || var.enable_grafana ? 1 : 0

  metadata {
    name = "monitoring"
    labels = merge(var.common_tags, {
      name = "monitoring"
    })
  }
}

resource "helm_release" "kube_prometheus_stack" {
  count = var.enable_prometheus || var.enable_grafana ? 1 : 0

  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "55.0.0"
  namespace  = kubernetes_namespace.monitoring[0].metadata[0].name

  values = [templatefile("${path.module}/values-prometheus.yaml", {
    grafana_password = coalesce(var.grafana_admin_password, random_password.grafana[0].result)
    alert_email      = var.alert_email
  })]

  depends_on = [kubernetes_namespace.monitoring]
}

resource "random_password" "grafana" {
  count = var.grafana_admin_password == null && var.enable_grafana ? 1 : 0

  length  = 24
  special = true
}

# ---------------------------------------------------------------------------------------------------------------------
# Datadog Secret Reference
# ---------------------------------------------------------------------------------------------------------------------

# The Datadog agent DaemonSet would be deployed via Helm in kubernetes/ manifests.
# This module creates the secret reference only.

resource "kubernetes_secret" "datadog_api_key" {
  count = var.datadog_api_key_secret_arn != null ? 1 : 0

  metadata {
    name      = "datadog-api-key"
    namespace = kubernetes_namespace.monitoring[0].metadata[0].name
  }

  data = {
    "api-key" = data.aws_secretsmanager_secret_version.datadog[0].secret_string
  }

  depends_on = [kubernetes_namespace.monitoring]
}

data "aws_secretsmanager_secret_version" "datadog" {
  count = var.datadog_api_key_secret_arn != null ? 1 : 0

  secret_id = var.datadog_api_key_secret_arn
}
