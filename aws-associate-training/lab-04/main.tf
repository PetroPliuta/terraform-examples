






### LAB 04



# aws --profile acloudguru elbv2 describe-target-health --target-group-arn $(aws --profile acloudguru elbv2 describe-target-groups --query 'TargetGroups[].TargetGroupArn' --output text) --query 'TargetHealthDescriptions[].TargetHealth.State'

