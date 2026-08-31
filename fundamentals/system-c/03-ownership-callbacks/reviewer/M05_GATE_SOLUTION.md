# P1-M05 Gate Reference Reasoning

The four faults are different contract failures:

1. callee frees a borrowed record: **ownership violation**;
2. creator publishes `*out` before construction commits and later frees it: **broken output/failure-state contract**;
3. callback registration stores a ctx pointer whose object is freed before invocation: **context lifetime violation**;
4. callback retains a record pointer explicitly documented as call-scoped borrow: **semantic retain violation**, which need not produce immediate memory-safety evidence.

The reference fix keeps construction local until success, leaves output NULL on failure, never frees borrowed records, keeps ctx live for all invocations, and copies only needed record values rather than retaining the pointer.
