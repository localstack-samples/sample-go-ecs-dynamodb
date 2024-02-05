


### Testing the application

```bash
curl -X POST https://lb-bee07cad.elb.localhost.localstack.cloud/post \
     -H "Content-Type: application/json" \
     -d '{
        "id": "1",
        "title": "my post #1",
        "content": "here is the post content",
        "status": "posted"
     }'
```

```bash
curl -X GET https://lb-bee07cad.elb.localhost.localstack.cloud/post/1
```