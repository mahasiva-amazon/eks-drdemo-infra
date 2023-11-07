provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
    kubernetes {
        host                   = data.aws_eks_cluster.this.endpoint
        cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
        token                  = data.aws_eks_cluster_auth.this.token
    }
}

data "aws_lb_target_group" "argoworkflow_webhooks_frontend" {
  name = "argoworkflow-webhooks-sns"
}

data "aws_lb_target_group" "argoworkflow_webhooks_frontend_tg_github" {
  name = "argoworkflow-webhooks-github"
}

data "aws_eks_cluster" "this" {
  name = "drworkshop"
}

data "aws_eks_cluster_auth" "this" {
    name = "drworkshop"
}

data "aws_lb" "webhook_alb" {
  name = "argoworkflow-webhooks-frontend"
}

resource "helm_release" "argoworkflow-event-bus" {
  name = "argoworkflow-event-bus"
  namespace  = "argo-events"
  chart = "./helm/eventbus"
}

resource "helm_release" "argoworkflow-eventsources" {
  depends_on = [helm_release.argoworkflow-event-bus]
  name = "argoworkflow-sns-eventsource"
  namespace  = "argo-events"
  chart = "./helm/eventsources"
  set {
    name = "events.sns_tg_arn"
    value = "${data.aws_lb_target_group.argoworkflow_webhooks_frontend.arn}"
  }
  set {
    name = "events.github_alb_dnsname"
    value = "${data.aws_lb.webhook_alb.dns_name}"
  }
  set {
    name = "events.github_tg_arn"
    value = "${data.aws_lb_target_group.argoworkflow_webhooks_frontend_tg_github.arn}"
  }
}

resource "helm_release" "argoworkflow-eventsensors" {
  name = "argoworkflow-sns-eventsensors"
  namespace  = "argo-events"
  chart = "./helm/eventsensors" 
}

resource "helm_release" "secretstore-csi-driver" {
  name       = "secrets-store-csi-driver"
  namespace  = "kube-system"

  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"

  set {
    name  = "syncSecret.enabled"
    value = "true"
  }
  set {
    name  = "enableSecretRotation"
    value = "true"
  }
}

resource "helm_release" "secretstore-ascp-provider" {
  name       = "secrets-provider-aws"
  namespace  = "kube-system"

  repository = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  chart      = "secrets-store-csi-driver-provider-aws"
}
