data "aws_caller_identity" "current" {}


resource "aws_codepipeline" "sample_app" {
  name     = "check_v2pipeline_app"
  role_arn = aws_iam_role.codepipeline.arn
  pipeline_type = "V2"

  artifact_store {
    location = aws_s3_bucket.codepipeline_artifact.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = 1
      output_artifacts = ["source_output"]
      configuration = {
        RepositoryName       = aws_codecommit_repository.sample_app.repository_name
        BranchName           = "release"
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }
  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = 1
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = aws_codebuild_project.build.id
      }
    }
  }
  # stage {
  #   name = "Deploy"
  #   action {
  #     name            = "Deploy"
  #     category        = "Deploy"
  #     owner           = "AWS"
  #     provider        = "ECS"
  #     version         = 1
  #     input_artifacts = ["build_output"]
  #     configuration = {
  #       ClusterName = aws_ecs_cluster.this.id
  #       ServiceName = aws_ecs_service.sample_app.name
  #     }
  #   }
  # }
}

# cloudwatch event rule
resource "aws_cloudwatch_event_rule" "codepipeline_sample_app" {
  name = "check_v2pipeline-sample-app"

  event_pattern = templatefile("./file/codepipeline_event_pattern.json", {
    codecommit_arn : aws_codecommit_repository.sample_app.arn
  })
}

# cloudwatchevent
resource "aws_cloudwatch_event_target" "codepipeline_sample_app" {
  rule     = aws_cloudwatch_event_rule.codepipeline_sample_app.name
  arn      = aws_codepipeline.sample_app.arn
  role_arn = aws_iam_role.event_bridge_codepipeline.arn
}

resource "aws_iam_role" "event_bridge_codepipeline" {
  name               = "check_v2pipeline-event-bridge-role"
  assume_role_policy = data.aws_iam_policy_document.event_bridge_assume_role.json
  inline_policy {
    name   = "codepipeline"
    policy = data.aws_iam_policy_document.event_bridge_codepipeline.json
  }
}

data "aws_iam_policy_document" "event_bridge_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codepipeline" {
  name = "check_v2pipeline-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "pipeline_service" {
  policy = file("./file/AWSCodePipelineServiceRole.json")
}

resource "aws_iam_role_policy_attachment" "attache_pipeline_service" {
  policy_arn = aws_iam_policy.pipeline_service.arn
  role       = aws_iam_role.codepipeline.name
}

data "aws_iam_policy_document" "event_bridge_codepipeline" {
  statement {
    actions   = ["codepipeline:StartPipelineExecution"]
    resources = ["${aws_codepipeline.sample_app.arn}"]
  }
}

resource "aws_iam_role" "build_role" {
  name = "codebuild-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Artifact用S3
resource "aws_s3_bucket" "codepipeline_artifact" {
  bucket = "artifact-store-${data.aws_caller_identity.current.account_id}"

}

# Codecommit repositroy
resource "aws_codecommit_repository" "sample_app" {
  repository_name = "MyTestRepository"
  description     = "This is the Sample App Repository"
}



# CodeBuild
resource "aws_codebuild_project" "build" {
  name         = "check_v2pipeline-buildproject"
  service_role = aws_iam_role.build_role.arn
  artifacts {
    type = "CODEPIPELINE"
  }
   environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true
  }
  source {
    type = "CODEPIPELINE"
  }
}