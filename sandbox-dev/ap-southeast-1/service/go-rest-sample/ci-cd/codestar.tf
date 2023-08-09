resource "aws_codestarconnections_connection" "release" {
  name          = "${local.identifier}-connection"
  provider_type = "GitHub"
}