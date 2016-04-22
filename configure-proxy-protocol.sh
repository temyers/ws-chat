#!/bin/bash

# http://www.raweng.com/blog/2014/11/11/websockets-on-aws-elb/

export ELB_NAME="test-elb-name"
REGION=us-east-1

export POLICY_NAME="policy-protocol-name"

#aws elb create-load-balancer-policy --load-balancer-name "vgw-chumb-haproxyE-57FBFX2IQL5V" --policy-name "$POLICY_NAME" --policy-type-name "ProxyProtocolPolicyType" --policy-attributes "AttributeName=ProxyProtocol,AttributeValue=True" 

aws elb set-load-balancer-policies-for-backend-server --load-balancer-name $ELB_NAME --instance-port 80 --policy-names $POLICY_NAME
aws elb set-load-balancer-policies-for-backend-server --load-balancer-name $ELB_NAME --instance-port 8080 --policy-names $POLICY_NAME

# Required for SSL
aws elb set-load-balancer-policies-for-backend-server --load-balancer-name $ELB_NAME --instance-port 443 --policy-names $POLICY_NAME
