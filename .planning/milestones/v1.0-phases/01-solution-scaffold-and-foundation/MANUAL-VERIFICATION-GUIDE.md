# Manual Verification: ProblemDetails Smoke Test

## Prerequisites

- .NET 10 SDK installed
- `curl` and `jq` available (or use Postman/browser)

## 1. Start the Application

```bash
cd F:/Personal/bootstrapper-apps/web-api
dotnet run --project src/Starter.WebApi
```

Wait for the console output:
```
Now listening on: http://localhost:5100
```

## 2. Test Each Endpoint

Open a **second terminal** and run each command. Every response must be valid JSON with these common fields:

| Field      | Description                          | Example                              |
|------------|--------------------------------------|--------------------------------------|
| `type`     | URL identifying the error type       | `https://httpstatuses.io/404`        |
| `title`    | Short human-readable summary         | `Not Found`                          |
| `status`   | HTTP status code (integer)           | `404`                                |
| `detail`   | Specific error message               | `Entity with ID 42 was not found.`   |
| `instance` | Request method + path                | `GET /api/diagnostics/not-found`     |
| `traceId`  | Unique request trace identifier      | `0HN9ABC123...`                      |

In Development mode, all responses also include `stackTrace`.

---

### Test 1: 404 Not Found

```bash
curl -s http://localhost:5100/api/diagnostics/not-found | jq .
```

**Expected:**
```json
{
  "type": "https://httpstatuses.io/404",
  "title": "Not Found",
  "status": 404,
  "detail": "Entity with ID 42 was not found.",
  "instance": "GET /api/diagnostics/not-found",
  "traceId": "<any string>",
  "stackTrace": "<present in Development>"
}
```

**Check:** Status is `404`, title is `"Not Found"`.

---

### Test 2: 422 Validation Failed

```bash
curl -s http://localhost:5100/api/diagnostics/validation | jq .
```

**Expected:**
```json
{
  "type": "https://httpstatuses.io/422",
  "title": "Validation Failed",
  "status": 422,
  "detail": "One or more validation errors occurred.",
  "instance": "GET /api/diagnostics/validation",
  "traceId": "<any string>",
  "stackTrace": "<present in Development>",
  "errors": {
    "Name": ["Name is required.", "Name must be at least 3 characters."],
    "Price": ["Price must be greater than zero."]
  }
}
```

**Check:** Status is `422`, `errors` object has `Name` (2 messages) and `Price` (1 message).

---

### Test 3: 409 Conflict

```bash
curl -s http://localhost:5100/api/diagnostics/conflict | jq .
```

**Expected:**
```json
{
  "type": "https://httpstatuses.io/409",
  "title": "Conflict",
  "status": 409,
  "detail": "An entity with that name already exists.",
  "instance": "GET /api/diagnostics/conflict",
  "traceId": "<any string>",
  "stackTrace": "<present in Development>"
}
```

**Check:** Status is `409`, title is `"Conflict"`.

---

### Test 4: 401 Unauthorized

```bash
curl -s http://localhost:5100/api/diagnostics/unauthorized | jq .
```

**Expected:**
```json
{
  "type": "https://httpstatuses.io/401",
  "title": "Unauthorized",
  "status": 401,
  "detail": "Authentication is required.",
  "instance": "GET /api/diagnostics/unauthorized",
  "traceId": "<any string>",
  "stackTrace": "<present in Development>"
}
```

**Check:** Status is `401`, detail is the default message `"Authentication is required."`.

---

### Test 5: 403 Forbidden

```bash
curl -s http://localhost:5100/api/diagnostics/forbidden | jq .
```

**Expected:**
```json
{
  "type": "https://httpstatuses.io/403",
  "title": "Forbidden",
  "status": 403,
  "detail": "You do not have permission to perform this action.",
  "instance": "GET /api/diagnostics/forbidden",
  "traceId": "<any string>",
  "stackTrace": "<present in Development>"
}
```

**Check:** Status is `403`, detail is the default message.

---

### Test 6: 500 Internal Server Error (unhandled)

```bash
curl -s http://localhost:5100/api/diagnostics/unhandled | jq .
```

**Expected:**
```json
{
  "type": "https://httpstatuses.io/500",
  "title": "Internal Server Error",
  "status": 500,
  "detail": "Something unexpected happened.",
  "instance": "GET /api/diagnostics/unhandled",
  "traceId": "<any string>",
  "stackTrace": "<present in Development>"
}
```

**Check:** Status is `500`, `stackTrace` is present (Development mode).

---

## 3. Quick Script (run all at once)

```bash
echo "=== 404 Not Found ===" && \
curl -s -w "\nHTTP Status: %{http_code}\n" http://localhost:5100/api/diagnostics/not-found | jq . && \
echo "=== 422 Validation ===" && \
curl -s -w "\nHTTP Status: %{http_code}\n" http://localhost:5100/api/diagnostics/validation | jq . && \
echo "=== 409 Conflict ===" && \
curl -s -w "\nHTTP Status: %{http_code}\n" http://localhost:5100/api/diagnostics/conflict | jq . && \
echo "=== 401 Unauthorized ===" && \
curl -s -w "\nHTTP Status: %{http_code}\n" http://localhost:5100/api/diagnostics/unauthorized | jq . && \
echo "=== 403 Forbidden ===" && \
curl -s -w "\nHTTP Status: %{http_code}\n" http://localhost:5100/api/diagnostics/forbidden | jq . && \
echo "=== 500 Unhandled ===" && \
curl -s -w "\nHTTP Status: %{http_code}\n" http://localhost:5100/api/diagnostics/unhandled | jq .
```

## 4. Pass/Fail Checklist

- [ ] All 6 endpoints return valid JSON (not HTML error pages)
- [ ] Each response has all 6 common fields (`type`, `title`, `status`, `detail`, `instance`, `traceId`)
- [ ] Status codes match: 404, 422, 409, 401, 403, 500
- [ ] 422 response has `errors` object with `Name` and `Price` keys
- [ ] All Development responses include `stackTrace`
- [ ] Server console shows `LogError` output for each request

## 5. Stop the Server

Press `Ctrl+C` in the terminal running the application.
