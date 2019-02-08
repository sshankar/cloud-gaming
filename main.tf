data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_vpc" "default" {
  default = "${var.vpc_id == "" ? true : false}"
  id      = "${var.vpc_id}"
}

data "aws_subnet_ids" "default" {
  vpc_id = "${data.aws_vpc.default.id}"
}

data "aws_subnet" "default" {
  count = "${length(data.aws_subnet_ids.default.ids)}"
  id    = "${element(data.aws_subnet_ids.default.ids, count.index)}"
}

# Looks for gamebox AMI if ami_id isn't specified.
data "aws_ami" "gamebox" {
  count = "${var.ami_id == "" ? 1 : 0}"

  most_recent = true
  owners = ["${data.aws_caller_identity.current.account_id}"]

  filter {
    name   = "platform"
    values = ["windows"]
  }

  filter {
    name   = "name"
    values = ["gamebox-windows-*"]
  }
}

resource "aws_security_group" "default" {
  name_prefix = "gamebox-allow-all-"
  description = "Relaxed security group allowing all inbound and outbound tcp/udp traffic"

  vpc_id = "${data.aws_vpc.default.id}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Service = "gamebox"
  }
}

# Gamebox recipies have autologin set, this is just in case.
resource "tls_private_key" "generated" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "rdp" {
  key_name_prefix = "gamebox-key-"
  public_key      = "${tls_private_key.generated.public_key_openssh}"
}

resource "aws_launch_template" "box" {
  count       = "${length(data.aws_subnet.default.*.id)}"
  name        = "gamebox-lt-${element(data.aws_subnet.default.*.availability_zone, count.index)}"
  description = "Launch template which can be used to provision a spot or on demand instance"

  placement {
    availability_zone = "${element(data.aws_subnet.default.*.availability_zone, count.index)}"
  }
  network_interfaces {
    associate_public_ip_address = true
    subnet_id                   = "${element(data.aws_subnet.default.*.id, count.index)}"
  }

  image_id               = "${var.ami_id}"
  instance_type          = "${var.spot_instance_type}"
  key_name               = "${aws_key_pair.rdp.key_name}"
  vpc_security_group_ids = ["${aws_security_group.default.id}"]

  monitoring {
    enabled = false
  }

  tag_specifications {
    resource_type = "instance"
    tags {
      Service = "gamebox"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags {
      Service = "gamebox"
    }
  }
}

data "aws_iam_policy_document" "assumed_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com", "ec2.amazonaws.com", "spotfleet.amazonaws.com", "spot.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "spot_crud" {
  statement {
    sid       = "passrole"
    actions   = ["iam:ListRoles", "iam:PassRole", "iam:ListInstanceProfiles"]
    resources = ["*"]
  }
  statement {
    sid       = "createslrsf"    
    actions   = ["iam:CreateServiceLinkedRole", "iam:DeleteServiceLinkedRole", "iam:GetServiceLinkedRoleDeletionStatus", "iam:UpdateRoleDescription", "iam:PutRolePolicy"]
    resources = ["arn:aws:iam::*:role/aws-service-role/spotfleet.amazonaws.com/AWSServiceRoleForEC2SpotFleet"]
    condition {
      test     = "StringLike"
      variable = "iam:AWSServiceName"
      values   = ["spotfleet.amazonaws.com"]
    }
  }
  statement {
    sid       = "createslrs"    
    actions   = ["iam:CreateServiceLinkedRole", "iam:DeleteServiceLinkedRole", "iam:GetServiceLinkedRoleDeletionStatus", "iam:UpdateRoleDescription", "iam:PutRolePolicy"]
    resources = ["arn:aws:iam::*:role/aws-service-role/spot.amazonaws.com/AWSServiceRoleForEC2Spot"]
    condition {
      test     = "StringLike"
      variable = "iam:AWSServiceName"
      values   = ["spot.amazonaws.com"]
    }
  }
  statement {
    sid       = "crudspot"
    actions   = ["ec2:CreateSpot*", "ec2:RequestSpot*", "ec2:Describe*", "ec2:CancelSpot*", "ec2:ModifySpot*", "ec2:Terminate*", "ec2:CreateTags"]
    resources = ["*"]
  }
  statement {
    sid       = "logscw"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "lambda_execution_role" {
  name_prefix        = "gamebox-lamda-role-"
  path               = "/"
  assume_role_policy = "${data.aws_iam_policy_document.assumed_role.json}"
}

resource "aws_iam_role_policy" "lambda_execution_policy" {
  name_prefix = "gamebox-lamda-policy-"
  role        = "${aws_iam_role.lambda_execution_role.id}"
  policy      = "${data.aws_iam_policy_document.spot_crud.json}"
}

data "archive_file" "setup_lambda" {
  type        = "zip"
  source_file = "${path.module}/code/setupfleet.py"
  output_path = "${path.module}/code/artifacts/setup.zip"
}

resource "aws_lambda_function" "startstop" {
  filename         = "${path.module}/code/artifacts/setup.zip"
  function_name    = "gamebox-setup-fleet"
  description      = "Creates a fleet request with lowest priced allocation strategy and all provisioned launch configurations."
  role             = "${aws_iam_role.lambda_execution_role.arn}"
  handler          = "setupfleet.handle"
  source_code_hash = "${data.archive_file.setup_lambda.output_base64sha256}"
  runtime          = "python3.7"

  environment {
    variables {
      lt_version_json = "${jsonencode(zipmap(aws_launch_template.box.*.id, aws_launch_template.box.*.latest_version))}"
      fleet_role_arn  = "${aws_iam_role.lambda_execution_role.arn}"
    }
  }
}

resource "aws_iot_topic_rule" "aws_button" {
  count = "${var.iot_button_gsn == "" ? 0 : 1}"

  name        = "gamebox_trigger_${var.iot_button_gsn}"
  description = "Trigger to setup/teardown game box spot fleet"
  enabled     = true
  sql         = "SELECT * FROM 'iotbutton/${var.iot_button_gsn}'"
  sql_version = "2016-03-23"

  lambda {
    function_arn = "${aws_lambda_function.startstop.arn}"
  }
}

resource "aws_lambda_permission" "allow_button_invoke" {
  count = "${var.iot_button_gsn == "" ? 0 : 1}"

  action         = "lambda:InvokeFunction"
  function_name  = "${aws_lambda_function.startstop.function_name}"
  principal      = "iot.amazonaws.com"
  source_account = "${data.aws_caller_identity.current.account_id}"
  source_arn     = "${aws_iot_topic_rule.aws_button.arn}"
}

data "archive_file" "notify_lambda" {
  type        = "zip"
  source_file = "${path.module}/code/notify.py"
  output_path = "${path.module}/code/artifacts/notify.zip"
}

resource "aws_lambda_function" "notify" {
  count = "${var.ifttt_webhook_url == "" ? 0 : 1}"

  filename         = "${path.module}/code/artifacts/notify.zip"
  function_name    = "gamebox-ifttt-notify"
  description      = "Cloudwatch events handler, invokes callback URL on interested events"
  role             = "${aws_iam_role.lambda_execution_role.arn}"
  handler          = "notify.handle"
  source_code_hash = "${data.archive_file.notify_lambda.output_base64sha256}"
  runtime          = "python3.7"

  environment {
    variables {
      webhook_url = "${var.ifttt_webhook_url}"
    }
  }
}

resource "aws_cloudwatch_event_rule" "ec2_events" {
  count = "${var.ifttt_webhook_url == "" ? 0 : 1}"

  name        = "gamebox-ec2-statechange"
  description = "Subscribe to EC2 State Change Events"

  event_pattern = <<PATTERN
{
  "source": [ "aws.ec2" ],
  "detail-type": [ "EC2 Instance State-change Notification" ],
  "detail": {
    "state": [ "running", "terminated" ]
  }
}
PATTERN
}

resource "aws_cloudwatch_event_rule" "spot_events" {
  count = "${var.ifttt_webhook_url == "" ? 0 : 1}"

  name        = "gamebox-spot-termination"
  description = "Subscribe to EC2 Spot Termination Warning"

  event_pattern = <<PATTERN
{
  "source": [ "aws.ec2" ],
  "detail-type": ["EC2 Spot Instance Interruption Warning" ],
  "detail": {
    "instance-action": [ "terminate" ]
  }
}
PATTERN
}

resource "aws_cloudwatch_event_target" "ec2_events_notify" {
  count = "${var.ifttt_webhook_url == "" ? 0 : 1}"

  arn  = "${aws_lambda_function.notify.arn}"
  rule = "${aws_cloudwatch_event_rule.ec2_events.name}"
}

resource "aws_cloudwatch_event_target" "spot_events_notify" {
  count = "${var.ifttt_webhook_url == "" ? 0 : 1}"

  arn  = "${aws_lambda_function.notify.arn}"
  rule = "${aws_cloudwatch_event_rule.spot_events.name}"
}

resource "aws_lambda_permission" "allow_ec2_events_notify_invoke" {
  count = "${var.ifttt_webhook_url == "" ? 0 : 1}"

  action         = "lambda:InvokeFunction"
  function_name  = "${aws_lambda_function.notify.function_name}"
  principal      = "events.amazonaws.com"
  source_account = "${data.aws_caller_identity.current.account_id}"
  source_arn     = "${aws_cloudwatch_event_rule.ec2_events.arn}"
}

resource "aws_lambda_permission" "allow_spot_events_notify_invoke" {
  count = "${var.ifttt_webhook_url == "" ? 0 : 1}"

  action         = "lambda:InvokeFunction"
  function_name  = "${aws_lambda_function.notify.function_name}"
  principal      = "events.amazonaws.com"
  source_account = "${data.aws_caller_identity.current.account_id}"
  source_arn     = "${aws_cloudwatch_event_rule.spot_events.arn}"
}