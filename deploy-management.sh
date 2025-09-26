
#!/bin/bash

REGION="eu-west-2"
ALB_NAME="bank-alb"
BLUE_TG_NAME="blue-tg"
GREEN_TG_NAME="green-tg"

get_listener_arn() {
    aws elbv2 describe-listeners \
        --load-balancer-arn $(aws elbv2 describe-load-balancers --names $ALB_NAME --query 'LoadBalancers[0].LoadBalancerArn' --output text --region $REGION) \
        --region $REGION \
        --query 'Listeners[0].ListenerArn' \
        --output text
}

get_target_group_arn() {
    aws elbv2 describe-target-groups \
        --names $1 \
        --region $REGION \
        --query 'TargetGroups[0].TargetGroupArn' \
        --output text
}

check_current_traffic() {
    echo "Checking current deployment status..."
    LISTENER_ARN=$(get_listener_arn)
    CURRENT_TG=$(aws elbv2 describe-listeners --listener-arn $LISTENER_ARN --region $REGION --query 'Listeners[0].DefaultActions[0].TargetGroupArn' --output text)
    BLUE_TG_ARN=$(get_target_group_arn $BLUE_TG_NAME)
    
    if [[ "$CURRENT_TG" == "$BLUE_TG_ARN" ]]; then
        echo "Current traffic: BLUE environment"
    else
        echo "Current traffic: GREEN environment"
    fi
    
    # Check target group health
    echo ""
    echo "Blue target group health:"
    aws elbv2 describe-target-health --target-group-arn $BLUE_TG_ARN --region $REGION --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' --output table
    
    echo ""
    echo "Green target group health:"
    GREEN_TG_ARN=$(get_target_group_arn $GREEN_TG_NAME)
    aws elbv2 describe-target-health --target-group-arn $GREEN_TG_ARN --region $REGION --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' --output table
}

switch_to_green() {
    echo "Switching traffic to GREEN environment..."
    LISTENER_ARN=$(get_listener_arn)
    GREEN_TG_ARN=$(get_target_group_arn $GREEN_TG_NAME)
    
    aws elbv2 modify-listener \
        --listener-arn $LISTENER_ARN \
        --default-actions Type=forward,TargetGroupArn=$GREEN_TG_ARN \
        --region $REGION
    
    if [ $? -eq 0 ]; then
        echo "SUCCESS: Traffic switched to GREEN environment"
        echo "Test URL: http://bank-alb-743777199.eu-west-2.elb.amazonaws.com"
    else
        echo "ERROR: Failed to switch traffic"
    fi
}

switch_to_blue() {
    echo "Rolling back to BLUE environment..."
    LISTENER_ARN=$(get_listener_arn)
    BLUE_TG_ARN=$(get_target_group_arn $BLUE_TG_NAME)
    
    aws elbv2 modify-listener \
        --listener-arn $LISTENER_ARN \
        --default-actions Type=forward,TargetGroupArn=$BLUE_TG_ARN \
        --region $REGION
    
    if [ $? -eq 0 ]; then
        echo "SUCCESS: Rollback complete - Traffic back to BLUE environment"
        echo "Application URL: http://bank-alb-743777199.eu-west-2.elb.amazonaws.com"
    else
        echo "ERROR: Failed to rollback traffic"
    fi
}

case $1 in
    "status"|"check")
        check_current_traffic
        ;;
    "green"|"deploy")
        switch_to_green
        ;;
    "blue"|"rollback")
        switch_to_blue
        ;;
    *)
        echo "Blue-Green Deployment Manager"
        echo ""
        echo "Usage: $0 {status|green|blue}"
        echo ""
        echo "Commands:"
        echo "  status  - Check current deployment and health status"
        echo "  green   - Switch traffic to green environment" 
        echo "  blue    - Rollback to blue environment"
        ;;
esac
