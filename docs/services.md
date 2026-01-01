## Skir services

### Calling a method with cURL

```
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"method": "MethodName", "request": {"foo": 3, "bar": []}}' \
  http://localhost:8787/myapi
```
