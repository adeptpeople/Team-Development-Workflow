# Example: Migrating `requests` → `httpx`

This example demonstrates the library-migration skill applied to the common
`requests` → `httpx` migration in a Python service.

---

## Invocation

```
/skill library-migration
Source library: requests 2.31.0
Target library: httpx 0.27.0
Scope: src/
```

---

## Example Inventory Output

```
MIGRATION INVENTORY
===================
Source library:  requests 2.31.0
Target library:  httpx 0.27.0

Files affected: 7
  - src/integrations/payment_gateway.py: 4 usages
  - src/integrations/shipping_provider.py: 6 usages
  - src/notifications/email_client.py: 2 usages
  - src/health/readiness_check.py: 1 usage
  - tests/test_payment_gateway.py: 3 usages (mock patches)
  - tests/test_shipping_provider.py: 5 usages (mock patches)
  - tests/conftest.py: 1 usage (session fixture)

API mappings identified:
  - requests.get(url, **kwargs) → httpx.get(url, **kwargs) [sync, direct]
  - requests.post(url, json=...) → httpx.post(url, json=...) [sync, direct]
  - requests.Session() → httpx.Client() [sync] or httpx.AsyncClient() [async]
  - requests.exceptions.RequestException → httpx.HTTPError
  - requests.exceptions.Timeout → httpx.TimeoutException
  - response.raise_for_status() → response.raise_for_status() [identical]
  - response.json() → response.json() [identical]

Estimated effort:
  - Automated: 16 locations (direct 1:1 mapping)
  - Manual:     2 locations (Session lifecycle management, requires context manager)
```

---

## Example API Mapping Table

| requests API                        | httpx equivalent                    | Notes                          |
|-------------------------------------|-------------------------------------|--------------------------------|
| `import requests`                   | `import httpx`                      | Direct                         |
| `requests.get(url)`                 | `httpx.get(url)`                    | Direct                         |
| `requests.post(url, json=data)`     | `httpx.post(url, json=data)`        | Direct                         |
| `requests.Session()`                | `httpx.Client()`                    | Use as context manager         |
| `session.mount("https://", ...)`    | `httpx.Client(transport=...)`       | Different transport API        |
| `requests.exceptions.Timeout`       | `httpx.TimeoutException`            | Import path changes            |
| `requests.exceptions.HTTPError`     | `httpx.HTTPStatusError`             | Subclass hierarchy changed     |
| `response.text`                     | `response.text`                     | Identical                      |
| `response.content`                  | `response.content`                  | Identical                      |
| `timeout=(connect, read)`           | `timeout=httpx.Timeout(read, connect=connect)` | Different signature |

---

## Example Edit Applied

**Before** (`src/integrations/payment_gateway.py`):
```python
import requests
from requests.exceptions import RequestException, Timeout

class PaymentGatewayClient:
    def __init__(self, base_url: str, api_key: str) -> None:
        self._base_url = base_url
        self._session = requests.Session()
        self._session.headers.update({"Authorization": f"Bearer {api_key}"})

    def charge(self, amount: int, currency: str) -> dict:
        try:
            response = self._session.post(
                f"{self._base_url}/charges",
                json={"amount": amount, "currency": currency},
                timeout=(3.05, 27),
            )
            response.raise_for_status()
            return response.json()
        except Timeout:
            raise PaymentTimeoutError("Gateway timed out")
        except RequestException as e:
            raise PaymentError(f"Gateway error: {e}")
```

**After**:
```python
import httpx

class PaymentGatewayClient:
    def __init__(self, base_url: str, api_key: str) -> None:
        self._base_url = base_url
        self._client = httpx.Client(
            headers={"Authorization": f"Bearer {api_key}"},
            timeout=httpx.Timeout(27.0, connect=3.05),
        )

    def charge(self, amount: int, currency: str) -> dict:
        try:
            response = self._client.post(
                f"{self._base_url}/charges",
                json={"amount": amount, "currency": currency},
            )
            response.raise_for_status()
            return response.json()
        except httpx.TimeoutException:
            raise PaymentTimeoutError("Gateway timed out")
        except httpx.HTTPError as e:
            raise PaymentError(f"Gateway error: {e}")
```

---

## Generated Checklist

```markdown
## Migration Checklist: requests → httpx

### Completed
- [x] Inventoried all usages (7 files, 18 occurrences)
- [x] Replaced all direct module-level imports
- [x] Migrated requests.Session() → httpx.Client() with context manager
- [x] Updated exception hierarchy (RequestException → HTTPError, Timeout → TimeoutException)
- [x] Updated Timeout tuple syntax to httpx.Timeout() object
- [x] Updated test mock patches (responses library → respx)
- [x] Linter passes (black, isort, mypy clean)
- [x] All 47 tests pass

### Requires Human Review
- [ ] src/integrations/shipping_provider.py:88 — custom retry adapter using requests.adapters.HTTPAdapter
  Note: httpx uses a different transport/retry API. Review httpx-retrying library.

### Out of Scope (Follow-up Tickets)
- [ ] PLAT-789: Migrate synchronous httpx.Client to httpx.AsyncClient for async routes
- [ ] Update requirements.txt: remove requests==2.31.0, add httpx==0.27.0
```
