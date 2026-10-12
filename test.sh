#!/bin/bash
# Smoke test for the deployed Fargate service: write a post through the
# load balancer, read it back, and check it landed in DynamoDB.
set -euo pipefail

MAX_ATTEMPTS=${MAX_ATTEMPTS:-30}
TABLE_NAME=blog-post-table

LB_DNS=$(lstk aws cloudformation describe-stacks --stack-name ddblocal-fargate-stack \
  --query "Stacks[0].Outputs[?starts_with(OutputKey, 'MyFargateServiceLoadBalancerDNS')].OutputValue | [0]" \
  --output text)
URL="http://$LB_DNS:4566"
echo "Service URL: $URL"

for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  if curl -sf -m 5 "$URL/health" > /dev/null; then
    break
  fi
  if [ "$attempt" -eq "$MAX_ATTEMPTS" ]; then
    echo "Test failed: service did not become healthy"
    exit 1
  fi
  echo "Attempt $attempt/$MAX_ATTEMPTS: service not healthy yet"
  sleep 5
done
echo "Service is healthy"

POST_ID="smoke-$(date +%s)"
# Print the status and body on errors instead of failing silently
request() {
  local body status
  body=$(curl -s -m 10 -w '\n%{http_code}' "$@")
  status=${body##*$'\n'}
  body=${body%$'\n'*}
  if [ "${status:0:1}" != "2" ]; then
    echo "Test failed: $* returned HTTP $status: $body" >&2
    return 1
  fi
  echo "$body"
}

created=$(request -X POST "$URL/post" \
  -H 'Content-Type: application/json' \
  -d "{\"id\":\"$POST_ID\",\"title\":\"Smoke test\",\"content\":\"Hello from CI\",\"status\":\"posted\"}")
echo "Created: $created"

fetched=$(request "$URL/post/$POST_ID")
echo "Fetched: $fetched"
if ! echo "$fetched" | jq -e --arg id "$POST_ID" '.id == $id and .title == "Smoke test" and .content == "Hello from CI"' > /dev/null; then
  echo "Test failed: fetched post does not match"
  exit 1
fi

stored=$(lstk aws dynamodb get-item --table-name "$TABLE_NAME" \
  --key "{\"id\": {\"S\": \"$POST_ID\"}}" --query 'Item.title.S' --output text)
if [ "$stored" != "Smoke test" ]; then
  echo "Test failed: post not found in DynamoDB table $TABLE_NAME"
  exit 1
fi

echo "Test passed: post was written through the service and stored in DynamoDB"
