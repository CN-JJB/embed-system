# M07 Hint Ladder

## Challenge
**Hint 1:** separate C object storage from external byte contract.  
**Hint 2:** write the 12-byte offset table and locate first golden mismatch.  
**Hint 3:** validate before publication; move signed representation with `memcpy`, not pointer-punning.

## Gate
**Hint 1:** there are layout/representation, endian, bounds, and output-state faults.  
**Hint 2:** use bytes for format semantics; sanitizer only for memory-safety symptom.  
**Hint 3:** destination changes before success, and flags are decoded in the opposite byte order.
