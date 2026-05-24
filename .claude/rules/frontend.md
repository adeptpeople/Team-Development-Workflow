---
description: Frontend component authoring rules for all UI source files
paths:
  - "src/ui/**/*"
  - "src/components/**/*"
  - "src/pages/**/*"
  - "src/app/**/*.tsx"
  - "src/app/**/*.ts"
---

# Frontend Rules — Scoped Rule

Applies to all files under `src/ui/`, `src/components/`, `src/pages/`, and `src/app/`.
These rules govern component design, accessibility, state, and styling.

---

## Component Conventions

- One component per file. File name = component name in kebab-case: `order-summary-card.tsx`.
- Components are **function components** exclusively. No class components.
- Props interface declared immediately before the component:
  ```tsx
  interface IOrderCardProps {
    orderId: string;
    status: OrderStatus;
    onCancel: (orderId: string) => void;
  }

  export function OrderCard({ orderId, status, onCancel }: IOrderCardProps) { ... }
  ```
- Destructure props in the function signature — never access `props.x` inside the body.
- Export named, not default. One named export per file for the primary component.
- Co-locate component-specific utilities, hooks, and types in the same directory.

### Component Size
- Maximum 150 lines per component file (excluding types and tests).
- Extract child components when a render section exceeds 30 lines.
- Extract custom hooks when state logic exceeds 20 lines.

---

## Accessibility (a11y)

- All interactive elements must be keyboard-navigable and have visible focus indicators.
- Images require `alt` text. Decorative images use `alt=""`.
- Form inputs must have associated `<label>` elements (not just placeholder text).
- Color alone must never convey meaning — pair with an icon or text.
- ARIA roles and attributes must be accurate. Do not use `role="button"` on a `<div>` — use `<button>`.
- All interactive UI must pass `axe-core` accessibility checks in tests.
- Minimum contrast ratio: 4.5:1 for normal text, 3:1 for large text (WCAG AA).
- Modal dialogs must trap focus while open and return focus on close.

```tsx
// Required pattern for icon-only buttons
<button
  type="button"
  aria-label="Cancel order"
  onClick={() => onCancel(orderId)}
>
  <XIcon aria-hidden="true" />
</button>
```

---

## State Management

- **Local state first**: use `useState` for component-local state.
- **Context for cross-component state** scoped to a feature subtree. One context per domain.
- **Server state via React Query** (`@tanstack/react-query`). No manual fetch + useEffect for server data.
- **Global client state via Zustand** for cross-cutting UI state (auth, theme, notifications).
- Forbidden patterns:
  - Prop drilling beyond 2 levels — use context or composition.
  - Storing server data in `useState` — use React Query cache.
  - Mutating state directly — always use setState/dispatch.
- Derived values must be computed (useMemo if expensive), never stored as separate state.

```tsx
// Correct — derived value via useMemo
const sortedOrders = useMemo(
  () => [...orders].sort((a, b) => b.createdAt - a.createdAt),
  [orders]
);

// Forbidden — duplicate state
const [sortedOrders, setSortedOrders] = useState<Order[]>([]);
useEffect(() => { setSortedOrders([...orders].sort(...)); }, [orders]);
```

---

## Styling Rules

- Use **Tailwind CSS** utility classes as the primary styling mechanism.
- Component variants managed via `cva` (class-variance-authority) — not ad-hoc ternary class strings.
- No inline `style={{}}` except for dynamic values that cannot be expressed as Tailwind classes.
- No custom CSS files for component styles. Global styles only in `src/app/globals.css`.
- Design tokens (colors, spacing, typography) must come from the Tailwind config — never hardcoded hex values in component files.
- Dark mode support required for all new components using Tailwind's `dark:` prefix.

```tsx
// Correct — variant-driven with cva
const buttonVariants = cva("rounded-md font-medium transition-colors", {
  variants: {
    intent: {
      primary: "bg-blue-600 text-white hover:bg-blue-700",
      danger: "bg-red-600 text-white hover:bg-red-700",
    },
  },
});
```

---

## Performance

- Images use `next/image` (or framework equivalent) with explicit `width` and `height`.
- Large lists use virtualization (`@tanstack/react-virtual`) when items exceed 100.
- Avoid anonymous functions in JSX render for stable references in event handlers — use `useCallback` when the handler is passed to memoized children.
- Code-split routes using dynamic imports. No monolithic bundle.
- Core Web Vitals targets: LCP < 2.5s, CLS < 0.1, INP < 200ms.

---

## Error Boundaries

- Every top-level route must be wrapped in an error boundary.
- Error boundaries must show a user-friendly fallback — not a blank screen or raw error.
- Log errors caught by boundaries to the observability service.

---

## Testing Components

- Unit test with `@testing-library/react`. No Enzyme.
- Test behavior from the user's perspective — query by role, label, text.
- Do not test implementation details (internal state, refs, method calls).
- Snapshot tests are discouraged. Use explicit assertions instead.
