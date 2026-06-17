resource "aws_api_gateway_rest_api" "this" {
  provider = aws

  name        = var.api_name
  description = "Data Products API - consulta via Athena com governanca Lake Formation."

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

locals {
  route_paths = {
    for key, route in var.routes : key => trim(route.path, "/")
  }

  path_node_list = distinct(flatten([
    for path in values(local.route_paths) : [
      for idx, segment in split("/", path) : {
        full_path   = join("/", slice(split("/", path), 0, idx + 1))
        segment     = segment
        depth       = idx + 1
        parent_path = idx == 0 ? null : join("/", slice(split("/", path), 0, idx))
      }
    ]
  ]))

  max_path_depth = max([for node in local.path_node_list : node.depth]...)

  path_nodes_by_depth = {
    for depth in range(1, local.max_path_depth + 1) :
    depth => {
      for node in local.path_node_list :
      node.full_path => node
      if node.depth == depth
    }
  }
}

resource "aws_api_gateway_resource" "depth_1" {
  for_each = lookup(local.path_nodes_by_depth, 1, {})

  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = each.value.segment
}

resource "aws_api_gateway_resource" "depth_2" {
  for_each = lookup(local.path_nodes_by_depth, 2, {})

  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.depth_1[each.value.parent_path].id
  path_part   = each.value.segment
}

resource "aws_api_gateway_resource" "depth_3" {
  for_each = lookup(local.path_nodes_by_depth, 3, {})

  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.depth_2[each.value.parent_path].id
  path_part   = each.value.segment
}

resource "aws_api_gateway_resource" "depth_4" {
  for_each = lookup(local.path_nodes_by_depth, 4, {})

  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.depth_3[each.value.parent_path].id
  path_part   = each.value.segment
}

locals {
  api_path_resources = merge(
    aws_api_gateway_resource.depth_1,
    aws_api_gateway_resource.depth_2,
    aws_api_gateway_resource.depth_3,
    aws_api_gateway_resource.depth_4,
  )

  route_resource_ids = {
    for route_key, path in local.route_paths :
    route_key => local.api_path_resources[path].id
  }

  deployment_trigger_hash = sha1(jsonencode({
    resources = sort(concat(
      [for k, r in aws_api_gateway_resource.depth_1 : "${k}:${r.id}"],
      [for k, r in aws_api_gateway_resource.depth_2 : "${k}:${r.id}"],
      [for k, r in aws_api_gateway_resource.depth_3 : "${k}:${r.id}"],
      [for k, r in aws_api_gateway_resource.depth_4 : "${k}:${r.id}"],
    ))
    methods = sort([
      for k, m in aws_api_gateway_method.get :
      "${k}:${m.id}:${m.http_method}:${m.api_key_required}"
    ])
    integrations = sort([
      for k, i in aws_api_gateway_integration.lambda :
      "${k}:${i.id}:${i.uri}"
    ])
  }))
}

resource "aws_api_gateway_method" "get" {
  for_each = var.routes

  rest_api_id      = aws_api_gateway_rest_api.this.id
  resource_id      = local.route_resource_ids[each.key]
  http_method      = "GET"
  authorization    = "NONE"
  api_key_required = var.api_key_required
}

resource "aws_api_gateway_integration" "lambda" {
  for_each = var.routes

  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = local.route_resource_ids[each.key]
  http_method = aws_api_gateway_method.get[each.key].http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = each.value.lambda_invoke_arn
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    redeployment = local.deployment_trigger_hash
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_api_gateway_integration.lambda]
}

resource "aws_api_gateway_stage" "this" {
  provider = aws

  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = var.stage_name
}

resource "aws_api_gateway_api_key" "this" {
  provider = aws

  name = "${var.api_name}-key"
}

resource "aws_api_gateway_usage_plan" "this" {
  provider = aws

  name = "${var.api_name}-usage-plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.this.id
    stage  = aws_api_gateway_stage.this.stage_name
  }

  throttle_settings {
    burst_limit = var.usage_plan_burst_limit
    rate_limit  = var.usage_plan_rate_limit
  }
}

resource "aws_api_gateway_usage_plan_key" "this" {
  key_id        = aws_api_gateway_api_key.this.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.this.id
}
