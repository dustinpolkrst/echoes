---
title: "Play Echoes"
description: "Echoes running in the browser, all 22 levels, with keyboard or a controller."
---

This is the whole game, built for the browser with [love.js](https://github.com/Davidobot/love.js), a WebAssembly build of LÖVE. Click the game to give it the keyboard. The first load is about 5 MB.

<div class="game">
  <div class="screen"><iframe id="echoes" src="game/" title="Echoes" allow="fullscreen; gamepad; autoplay" loading="lazy"></iframe></div>
  <div class="bar">
    <button type="button" id="echoes-full">Fullscreen</button>
    <span id="echoes-note">Progress saves in this browser. <kbd>F</kbd> in the game also toggles fullscreen.</span>
  </div>
</div>

<script>
  (function () {
    var frame = document.getElementById('echoes');
    var game = frame.parentNode.parentNode;
    var note = document.getElementById('echoes-note');
    var button = document.getElementById('echoes-full');
    function fsElement() {
      return document.fullscreenElement || document.webkitFullscreenElement || null;
    }
    function refused() {
      note.textContent = 'This browser would not go fullscreen here. Try F inside the game, or open the game on its own page.';
    }
    function exitFs() {
      var exit = document.exitFullscreen || document.webkitExitFullscreen;
      if (exit) exit.call(document);
    }
    // Esc inside the frame does not reach this page. While the page itself is fullscreen,
    // leave fullscreen instead of letting that key only pause the game. In-game F fullscreens
    // the frame document, and the page then reports the frame, so that key is left alone.
    function bindFrameKeys() {
      var win;
      try { win = frame.contentWindow; } catch (e) { return; }
      if (!win || win.__echoesPageFs) return;
      win.__echoesPageFs = true;
      win.addEventListener('keydown', function (e) {
        if (e.key !== 'Escape') return;
        var current = fsElement();
        if (!current || current === frame) return;
        e.preventDefault();
        e.stopImmediatePropagation();
        exitFs();
      }, true);
    }
    frame.addEventListener('load', bindFrameKeys);
    bindFrameKeys();
    button.addEventListener('click', function () {
      if (fsElement()) return exitFs();
      var request = game.requestFullscreen || game.webkitRequestFullscreen;
      if (!request) return refused();
      try {
        var result = request.call(game);
        if (result && result.catch) result.catch(refused);
      } catch (e) {
        refused();
      }
      frame.focus();
      try { frame.contentWindow.focus(); } catch (err) {}
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
