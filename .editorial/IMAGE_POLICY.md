# Image and Diagram Policy

## Purpose

Visuals exist to explain mechanisms, show evidence, or document hardware. They are not decoration.

## Preferred Visual Types

1. original Mermaid/SVG architecture diagrams;
2. sequence diagrams;
3. memory maps;
4. timing diagrams;
5. state machines;
6. annotated schematics created for the lesson;
7. oscilloscope / logic-analyzer captures from real experiments;
8. debugger, tracing, and terminal evidence;
9. hardware photos when they clarify setup or bring-up.

## Original-First Rule

Prefer redrawing a concept in an original diagram rather than copying a third-party figure.

A diagram should answer a teaching question such as:

- Where does data flow?
- Which component owns this address?
- What changes during context switch?
- Where can DMA/cache incoherency arise?
- Which stage of boot is currently failing?

## Third-Party Figures

If a third-party figure is genuinely necessary:

- use the original authoritative source;
- verify license/permission;
- record source and license;
- avoid copying if permission is unclear;
- never use random search-engine images as teaching assets.

## Experimental Evidence

Screenshots, waveforms, benchmark plots, logs, and photos must be clearly labeled as:

- real measured evidence;
- simulated/illustrative;
- expected example.

Never fabricate an “actual” waveform, terminal output, benchmark number, or debugger screenshot.

## Diagram Maintenance

Version-sensitive diagrams must state their baseline when appropriate, especially for:

- SoC architecture;
- boot flow;
- kernel subsystem implementation;
- project-specific device trees;
- register maps.

## Accessibility

Prefer readable text, high contrast, and diagrams that remain understandable without color-only distinctions.
