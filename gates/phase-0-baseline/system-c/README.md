# Module A — System C

**Time box:** 90 min  
**Score:** 15 points  
**Mode:** AI-Free; documentation allowed

## A1 — Telemetry Bug Hunt (55 min, 10 pts)

Starter: `starter/telemetry_bug_hunt.c`

The program is intentionally plausible rather than maximally broken. It contains a small set of real C defects around lifetime, bounds, `sizeof`, undefined behavior, wire layout/endian assumptions, and ownership.

### Required work

1. Build with strict warnings.
2. Run the program and record the first observable symptom.
3. Use any of GDB, AddressSanitizer, UndefinedBehaviorSanitizer, or compiler diagnostics to collect evidence.
4. Identify the independent defects you can prove. For each: state the root cause and whether it is undefined behavior, implementation/ABI-dependent behavior, or an API/ownership defect.
5. Repair the program without merely suppressing diagnostics.
6. Add or run regression checks that would fail on the original defect and pass on the repaired code.
7. Answer:
   - Which objects live on the stack, heap, and static storage in this program?
   - Which `sizeof` expressions depend on the pointed-to object and which only see a pointer type?
   - Why is copying a wire-format byte sequence directly into a normal C struct not a portable decoder?
   - Which returned pointer has ambiguous ownership? Redesign that API contract explicitly.

Suggested build commands:

```sh
gcc -std=c11 -g3 -O0 -Wall -Wextra -Wpedantic \
  starter/telemetry_bug_hunt.c -o telemetry_bug_hunt

gcc -std=c11 -g3 -O0 -Wall -Wextra -Wpedantic \
  -fsanitize=address,undefined -fno-omit-frame-pointer \
  starter/telemetry_bug_hunt.c -o telemetry_bug_hunt_san
```

Do not assume every defect will manifest on every compiler run. Explain what evidence proves the language/API problem.

## A2 — Callback Event Bus (35 min, 5 pts)

Files:

- `starter/event_bus.h`
- `starter/event_bus.c`
- `fixtures/test_event_bus.c`

Implement the missing event-bus functions. Do not change the public function signatures or the supplied tests except to add additional regression cases.

Required semantics:

- create a bus with fixed capacity supplied at runtime;
- register `(handler, ctx)` and return a non-zero token;
- emit an event to all currently registered handlers;
- unregister by token;
- reject invalid arguments and capacity exhaustion cleanly;
- `event_bus_destroy(&bus)` releases owned storage and sets the caller's pointer to `NULL`;
- the bus **borrows** `ctx`; it never frees or copies the pointed-to object;
- `data` passed to `event_bus_emit` is read-only and valid only for the duration of the call unless the caller documents a longer lifetime.

### Explain in your submission

- why `event_bus_create(struct event_bus **out, ...)` is a pointer-to-pointer API;
- who owns the bus object, handler context, and event data;
- what can go wrong if a registered `ctx` points to a dead stack object;
- what `const void *data` does and does not promise;
- how unregister behaves for an unknown token.

Run:

```sh
make event-bus-test
```
