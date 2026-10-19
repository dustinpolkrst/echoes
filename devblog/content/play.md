---
title: "Play Echoes"
description: "Echoes running in the browser, all 22 levels, with keyboard or a controller."
---

This is the whole game, built for the browser with [love.js](https://github.com/Davidobot/love.js), a WebAssembly build of LÖVE. Click the game to give it the keyboard. The first load is about 5 MB.

<div class="game">
  <div class="screen"><iframe id="echoes" src="game/" title="Echoes" allow="fullscreen; gamepad; autoplay" loading="lazy"></iframe></div>
  <div class="bar">
    <button type="button" id="echoes-full">Fullscreen</button>
    <span>Progress saves in this browser.</span>
  </div>
</div>

<script>
  (function () {
    var frame = document.getElementById('echoes');
    document.getElementById('echoes-full').addEventListener('click', function () {
      (frame.requestFullscreen || frame.webkitRequestFullscreen).call(frame);
      frame.contentWindow.focus();
    });
  })();
</script>

## Controls

| Action | Keyboard | Gamepad |
| --- | --- | --- |
| Move | <kbd>Left</kbd> <kbd>Right</kbd> or <kbd>A</kbd> <kbd>D</kbd> | D-pad or left stick |
| Jump (hold for height) | <kbd>Z</kbd>, <kbd>Space</kbd>, <kbd>W</kbd> or <kbd>Up</kbd> | A |
| Cast an echo | <kbd>X</kbd> or <kbd>K</kbd> | X or B |
| Rewind (hold) | <kbd>C</kbd> or <kbd>Shift</kbd> | Y or a shoulder button |
| Retry from the last waystone | <kbd>R</kbd> | Back |
| Pause | <kbd>Esc</kbd> or <kbd>P</kbd> | Start |

[About the game]({{< relref "about" >}}) explains how an echo behaves and what each tile does.

## How the browser build differs

It runs LÖVE 11.4, the newest version love.js ships, instead of 11.5. Nothing in Echoes depends on the difference. A browser has no window to quit or make fullscreen, so the menus leave out Quit and the Fullscreen setting, and the button under the game does fullscreen instead. Progress and settings live in this browser's storage, separate from a desktop install.
