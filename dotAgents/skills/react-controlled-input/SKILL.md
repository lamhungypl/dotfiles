---
name: react-controlled-input
description: Use when a controlled React input loses its user-typed value after a parent/context state update, option selection, or prop change — where the new derived state is empty/irrelevant and should not override what the user entered.
---

# Preserve Controlled Input Value

## Overview

A controlled input driven by derived state can have its value wiped when the parent changes state for unrelated reasons. The fix: track the last user-typed value in a ref and use it as a fallback when the derived state becomes empty.

## When to Use

- Controlled input clears when user selects an option or changes a mode
- External/context state changes cause `strippedInitialValue` (or equivalent) to become `''`
- You want "input retains whatever the user typed" across parent state transitions
- **Not needed** when the external reset IS intentional (e.g. "Try again", submit, clear button)

## Core Pattern

```tsx
// Track what the user actually typed — independent of derived state
const lastKnownValueRef = useRef(strippedInitialValue);

const handleInputChange = useCallback((value: string) => {
  lastKnownValueRef.current = value;   // always keep it fresh
  setInputValues([value, ...]);
}, []);

useEffect(() => {
  setInputValues((prev) => {
    // When external state becomes empty for a non-reset reason,
    // fall back to the last thing the user typed.
    const isExternalEmpty = isSpecialMode && !strippedInitialValue;
    const nextValue = isExternalEmpty ? lastKnownValueRef.current : strippedInitialValue;
    const nextAux   = isExternalEmpty ? prev[1] : answer?.evaluateValue || '';

    if (prev[0] === nextValue && prev[1] === nextAux) return prev;   // bail out early

    needsSyncRef.current = true;
    return [nextValue, nextAux];
  });
}, [strippedInitialValue, answer?.evaluateValue, isSpecialMode]);
```

## Key Points

| Concern | Approach |
|---|---|
| When to fall back | `isSpecialMode && !derivedValue` — empty for a mode reason, not a reset |
| When NOT to fall back | Intentional resets: "Try again", submit, clear → use `''` directly |
| Avoid sync loop | Early-return `prev` when nothing changes |
| Secondary value (`latexValue`) | Preserve `prev[1]` alongside the ref value |

## Relation to `useControllableState` (Radix/shadcn trend)

Radix UI's [`useControllableState`](https://vercel.com/academy/shadcn-ui/use-controllable-state) solves the related problem of hybrid controlled/uncontrolled components:

```tsx
const [value, setValue] = useControllableState({
  prop: controlledValue,      // external prop (controlled mode)
  defaultProp: defaultValue,  // initial value (uncontrolled mode)
  onChange: onValueChange,
});
```

Use `useControllableState` when **the component itself decides** whether it's controlled or not. Use the `lastKnownValueRef` pattern when the component is **always controlled** but one specific external state transition should not reset the value.

## Common Mistakes

- **Updating the ref inside the effect** — too late; update it in the onChange handler only
- **Using state instead of ref** — causes extra renders and potential loops
- **Applying the fallback unconditionally** — check the reason the derived value is empty first; intentional resets must still work

## Real Example

`MathFieldAsInput` in a special MCQ question: selecting "No solution" sets `originalValue` to a special constant → `getInitialMathFieldInSpecialMCQ()` returns `''` → without this pattern, the math input wipes. With `lastKnownAmValueRef`, the input keeps the user's formula while the MCQ option is selected.
