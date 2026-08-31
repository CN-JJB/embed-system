# P1-M05 Gate Hint Ladder

## Hint 1

Separate **object lifetime** from **release responsibility**. Which pointer is only borrowed?

## Hint 2

For `frame_create`, inspect every write to `*out`. Can failure leave caller with an ambiguous non-null value?

## Hint 3

For callback ctx, draw registration/invocation timeline. Does the context object still exist at invocation?

## Hint 4

A `const struct record *` can still be improperly retained. Ask what the synchronous contract says, not what ASan says.
