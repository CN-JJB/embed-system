# Fault Investigation: Fixture `f1`

## Scenario-Reported Symptom (Scenario-provided symptom, not author-captured evidence)
The system is configured to protect a shared resource between Task Low (Priority 1) and Task High (Priority 3). Under light load, Task High completes its processing with low latency (~1 ms). However, when background computation (Task Medium, Priority 2) is triggered, Task High experiences sudden, severe latency spikes exceeding 25 ms. A logic analyzer shows Task Medium running and preempting Task Low while Task High remains stuck in the Blocked state, despite Priority Inheritance supposedly being enabled.

## Objective
Diagnose why priority inheritance fails to boost Task Low when Task High blocks, identify the synchronization primitive type mismatch, and restore priority inheritance.

## Build
```bash
make -C fundamentals/rtos/03-freertos-priority-inversion-stack-watchdog/faults/f1 clean all
```
