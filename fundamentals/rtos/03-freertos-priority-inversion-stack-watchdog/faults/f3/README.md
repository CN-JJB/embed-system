# Fault Investigation: Fixture `f3`

## Scenario-Reported Symptom (Scenario-provided symptom, not author-captured evidence)
The developer configured a mutex (`xSemaphoreCreateMutex()`) with Priority Inheritance enabled to solve priority inversion between Task Low (Priority 1) and Task High (Priority 3). However, when Task Medium (Priority 2) runs, Task High continues to experience long delays (~20 ms) before acquiring the mutex. Logic analyzer traces show that while Task Low holds the mutex, Task Medium inexplicably executes anyway, defying the expected priority inheritance protection.

## Objective
Diagnose why Task Medium is able to run while Task Low holds the mutex, identify the inappropriate voluntary delay call inside the critical section, and restore non-blocking execution.

## Build
```bash
make -C fundamentals/rtos/03-freertos-priority-inversion-stack-watchdog/faults/f3 clean all
```
