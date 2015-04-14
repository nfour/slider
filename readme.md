# Slider

Browserified module. See `Slider.coffee`.

Cool features:
- By using the `absolute` option you can hide items to prevent them from being rendered when they needent be with `hideInactive`. This gives a huge performance boost when your slides are very complex.
- Animator agnostic. Supports `transit`, `velocity` and default jquery `animate`
- Generates markup from the minimal set of html elements.

Dependencies:
- `bluebird`
- `jquery`
- Uses a merge function from a library, just merges two objects together recursively.
