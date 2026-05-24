---
description: Test authoring standards for all test files
paths:
  - "**/*.test.ts"
  - "**/*.test.tsx"
  - "**/*.spec.ts"
  - "**/*.spec.tsx"
  - "tests/**/*.py"
  - "test_*.py"
  - "**/test_*.py"
  - "**/*_test.py"
---

# Testing Standards — Scoped Rule

Applies to all test files across the repository.
These rules are authoritative for test authoring regardless of language.

---

## AAA Pattern (Arrange → Act → Assert)

Every test must follow the AAA structure with clear visual separation:

```python
def test_create_order_returns_order_id_on_success():
    # Arrange
    customer = CustomerFactory.create(status=CustomerStatus.ACTIVE)
    payload = CreateOrderRequest(sku="WIDGET-001", quantity=2, customer_id=customer.id)

    # Act
    result = order_service.create_order(payload)

    # Assert
    assert result.order_id is not None
    assert result.status == OrderStatus.PENDING
```

```typescript
it("returns 422 when SKU is missing", async () => {
  // Arrange
  const payload = { quantity: 1 };

  // Act
  const response = await request(app).post("/v1/orders").send(payload);

  // Assert
  expect(response.status).toBe(422);
  expect(response.body.error.code).toBe("VALIDATION_ERROR");
});
```

- Do not mix arrangement and assertion. Never assert inside a loop over test data.
- Each test must have **exactly one logical assertion group** per behavior under test.
  Multiple `expect()` / `assert` calls are fine when they all verify the same outcome.

---

## Deterministic Tests

- Tests must produce identical results on every run, on every machine.
- **Forbidden non-determinism sources**:
  - `datetime.now()` / `Date.now()` without clock control.
  - `random` / `Math.random()` without seed.
  - File system state from previous test runs.
  - Network calls (real HTTP, DNS lookups).
  - Thread/process ordering without synchronization.
- Control time: use `freezegun` (Python) or `vi.setSystemTime()` / `jest.useFakeTimers()` (TS).
- Seed randomness when you must use it.
- Tests must be **order-independent**: passing in any sequence.

---

## No Real Network Calls

- Unit tests: no real I/O. Mock all external calls.
- Integration tests: use test doubles (containers, local stubs) — never production or staging services.
- Acceptable doubles:
  - `responses` / `httpretty` (Python HTTP mocking)
  - `msw` (TypeScript HTTP mocking for fetch/axios)
  - `testcontainers` for databases and queues
- Patterns that are forbidden:
  ```python
  # FORBIDDEN — real network call in a test
  result = requests.get("https://api.example.com/users")
  ```
  ```typescript
  // FORBIDDEN — real fetch in a unit test
  const data = await fetch("https://api.example.com/users");
  ```

---

## Fixture Reuse

- Common fixtures belong in `conftest.py` (Python) or `__fixtures__/` (TypeScript).
- Factory classes (using `factory_boy` or equivalent) are the canonical way to create test objects.
- Do not duplicate object creation logic across test files — extract to factories.
- Fixtures must have minimal scope: prefer function scope over session scope unless the fixture is expensive and truly stateless.
- Fixtures must clean up after themselves (teardown / `yield` pattern in pytest).

---

## Explicit Assertions

- Assert the specific value, not just truthiness:
  ```python
  # Bad — passes for any truthy value
  assert result

  # Good — verifies the actual value
  assert result.status == OrderStatus.CONFIRMED
  assert result.order_id == expected_order_id
  ```
- For exception tests, assert both the exception type **and** message:
  ```python
  with pytest.raises(OrderNotFoundError) as exc_info:
      order_service.get_order("nonexistent-id")
  assert "nonexistent-id" in str(exc_info.value)
  ```
- Use `assert_called_once_with` / `toHaveBeenCalledWith` — not just `assert_called` / `toHaveBeenCalled`.

---

## Test Naming

- Test names must read as behavior statements:
  - `test_<subject>_<action>_<expected_outcome>`
  - `test_create_order_raises_when_customer_inactive`
  - `test_get_order_returns_404_for_unknown_id`
- Group related tests in a class (`TestOrderService`) or `describe` block.
- Describe blocks name the unit under test; `it` / `test` blocks name the specific behavior.

---

## Mocking Policy

- Mock at the **boundary of the system under test**, not deep inside it.
- Prefer real implementations for simple collaborators. Mock only I/O and non-determinism.
- Never mock the module or class under test itself.
- Prefer dependency injection over `patch`-style monkey-patching where possible.
- When using `patch`, target the import path where the name is used, not where it is defined:
  ```python
  # Correct — patch where it's imported
  @patch("src.orders.service.send_email")
  ```

---

## Coverage

- New code must not reduce overall coverage below 85%.
- Exemptions (`# pragma: no cover`, `/* c8 ignore */`) require a comment explaining why.
- Coverage is measured in CI on every PR. Ratchet: coverage can only go up or stay the same.

---

## Regression Tests for Bug Fixes

When fixing a bug, the test must:
1. Reproduce the bug (test fails before fix).
2. Be committed in the same PR as the fix (test passes after fix).
3. Reference the issue/ticket in a comment: `# Regression: ORD-456`.
