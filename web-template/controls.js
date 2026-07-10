(function () {
  // Fake gamepad scaffold — injected before DOMContentLoaded so Emscripten's
  // SDL layer reads it on startup via navigator.getGamepads(). Lets the
  // on-screen "gamepad mode" buttons simulate a real controller for testing
  // controller support in a browser with no physical gamepad attached.
  window.__fakeGamepad = {
    id: 'Fake Gamepad',
    index: 0,
    mapping: 'standard',
    connected: false,
    timestamp: 0,
    axes: [0, 0, 0, 0],
    buttons: (function () {
      var btns = [];
      for (var i = 0; i < 16; i++) { btns.push({ pressed: false, value: 0 }); }
      return btns;
    }())
  };
  navigator.getGamepads = function () {
    return window.__fakeGamepad.connected ? [window.__fakeGamepad] : [];
  };

  // Ensure viewport meta tag exists for correct mobile scaling
  if (!document.querySelector('meta[name="viewport"]')) {
    var meta = document.createElement('meta');
    meta.name = 'viewport';
    meta.content = 'width=device-width, initial-scale=1.0';
    document.head.appendChild(meta);
  }

  // love.js sets canvas dimensions via JS inline styles after page load.
  // CSS !important alone loses that race, so we force-apply via setProperty
  // every 100 ms for the first 3 seconds, then on every resize.
  function scaleCanvas() {
    var c = document.getElementById('canvas');
    if (!c) return;
    var vw = window.innerWidth;
    var vh = Math.round(vw * 720 / 1280);
    c.style.setProperty('width',  vw + 'px', 'important');
    c.style.setProperty('height', vh + 'px', 'important');
  }
  scaleCanvas();
  window.addEventListener('resize', scaleCanvas);
  var _poll = setInterval(scaleCanvas, 100);
  setTimeout(function () { clearInterval(_poll); }, 3000);

  var style = document.createElement('style');
  style.textContent = [
    'html, body {',
    '  margin: 0;',
    '  padding: 0;',
    '  background: #000;',
    '  overflow-x: hidden;',
    '}',
    '#game-controls {',
    '  display: flex;',
    '  flex-direction: row;',
    '  align-items: center;',
    '  justify-content: space-between;',
    '  padding: 12px;',
    '  background: rgba(0,0,0,0.7);',
    '  width: 100%;',
    '  box-sizing: border-box;',
    '}',
    '#game-controls .cluster-left {',
    '  display: grid;',
    '  grid-template-columns: repeat(3, 60px);',
    '  grid-template-rows: repeat(2, 60px);',
    '  gap: 6px;',
    '}',
    '#game-controls .cluster-right {',
    '  display: grid;',
    '  grid-template-columns: repeat(2, 60px);',
    '  grid-template-rows: repeat(2, 60px);',
    '  gap: 6px;',
    '}',
    '#game-controls .cluster-gamepad-left {',
    '  display: grid;',
    '  grid-template-columns: repeat(3, 60px);',
    '  grid-template-rows: repeat(2, 60px);',
    '  gap: 6px;',
    '}',
    '#game-controls .cluster-gamepad-right {',
    '  display: grid;',
    '  grid-template-columns: repeat(2, 60px);',
    '  grid-template-rows: 60px;',
    '  gap: 6px;',
    '}',
    '#game-controls button.btn-action {',
    '  display: flex;',
    '  flex-direction: column;',
    '  align-items: center;',
    '  justify-content: center;',
    '  line-height: 1.1;',
    '}',
    '#game-controls button.btn-action .btn-key  { font-size: 16px; font-weight: bold; }',
    '#game-controls button.btn-action .btn-label { font-size: 10px; opacity: 0.75; }',
    '#game-controls button {',
    '  min-width: 60px;',
    '  min-height: 60px;',
    '  background: rgba(255,255,255,0.15);',
    '  color: white;',
    '  border: 1px solid rgba(255,255,255,0.3);',
    '  border-radius: 8px;',
    '  font-size: 18px;',
    '  cursor: pointer;',
    '  user-select: none;',
    '  -webkit-user-select: none;',
    '  touch-action: none;',
    '}',
    '#game-controls button:active {',
    '  background: rgba(255,255,255,0.35);',
    '}',
    '#game-controls .btn-toggle {',
    '  min-width: 40px;',
    '  min-height: 40px;',
    '  background: rgba(255,255,255,0.1);',
    '  color: white;',
    '  border: 1px solid rgba(255,255,255,0.3);',
    '  border-radius: 8px;',
    '  font-size: 16px;',
    '  cursor: pointer;',
    '  user-select: none;',
    '  -webkit-user-select: none;',
    '  touch-action: none;',
    '  align-self: center;',
    '}',
    '#game-controls .btn-up    { grid-column: 2; grid-row: 1; }',
    '#game-controls .btn-left  { grid-column: 1; grid-row: 2; }',
    '#game-controls .btn-down  { grid-column: 2; grid-row: 2; }',
    '#game-controls .btn-right { grid-column: 3; grid-row: 2; }',
    '#game-controls .btn-pickup { grid-column: 1; grid-row: 1; }',
    '#game-controls .btn-rotate { grid-column: 2; grid-row: 1; }',
    '#game-controls .btn-esc    { grid-column: 1 / span 2; grid-row: 2; }',
    '#game-controls .btn-gp-up    { grid-column: 2; grid-row: 1; }',
    '#game-controls .btn-gp-left  { grid-column: 1; grid-row: 2; }',
    '#game-controls .btn-gp-down  { grid-column: 2; grid-row: 2; }',
    '#game-controls .btn-gp-right { grid-column: 3; grid-row: 2; }',
    '#game-controls .btn-gp-a { grid-column: 1; grid-row: 1; }',
    '#game-controls .btn-gp-x { grid-column: 2; grid-row: 1; }'
  ].join('\n');
  document.head.appendChild(style);

  // love.js's WASM SDL layer reads e.keyCode (a legacy numeric code) to
  // determine which key was pressed. Synthetic events default to keyCode=0
  // which SDL maps to nothing, so all button presses are silently ignored.
  var KEY_CODES = {
    'w': 87, 'a': 65, 's': 83, 'd': 68, 'Escape': 27, 'e': 69, 'r': 82
  };

  document.addEventListener('DOMContentLoaded', function () {
    var canvas = document.getElementById('canvas');

    function fireKey(type, key, code) {
      if (!canvas) { canvas = document.getElementById('canvas'); }
      if (!canvas) { return; }
      var kc = KEY_CODES[key] || 0;
      canvas.dispatchEvent(new KeyboardEvent(type, {
        key: key, code: code,
        keyCode: kc, which: kc, charCode: kc,
        bubbles: true, cancelable: true
      }));
    }

    function attachButton(btn, key, code) {
      btn.addEventListener('mousedown',  function ()  { fireKey('keydown', key, code); });
      btn.addEventListener('mouseup',    function ()  { fireKey('keyup',   key, code); });
      btn.addEventListener('mouseleave', function ()  { fireKey('keyup',   key, code); });
      btn.addEventListener('touchstart', function (e) { e.preventDefault(); fireKey('keydown', key, code); }, { passive: false });
      btn.addEventListener('touchend',   function (e) { e.preventDefault(); fireKey('keyup',   key, code); }, { passive: false });
      btn.addEventListener('touchcancel',function (e) { e.preventDefault(); fireKey('keyup',   key, code); }, { passive: false });
    }

    // Fake gamepad button helper. Release is deferred by two rAF ticks so
    // the pressed=true state spans at least one full SDL poll cycle (LÖVE
    // samples the gamepad once per frame; a tap that lands entirely between
    // two polls would otherwise never be seen as pressed).
    function attachGamepadButton(btn, index) {
      var releaseRaf = null;
      function gpPress() {
        if (releaseRaf) { cancelAnimationFrame(releaseRaf); releaseRaf = null; }
        window.__fakeGamepad.buttons[index].pressed = true;
        window.__fakeGamepad.buttons[index].value = 1;
        window.__fakeGamepad.timestamp = performance.now();
      }
      function gpRelease() {
        if (releaseRaf) cancelAnimationFrame(releaseRaf);
        releaseRaf = requestAnimationFrame(function () {
          releaseRaf = requestAnimationFrame(function () {
            releaseRaf = null;
            window.__fakeGamepad.buttons[index].pressed = false;
            window.__fakeGamepad.buttons[index].value = 0;
          });
        });
      }
      btn.addEventListener('mousedown', gpPress);
      btn.addEventListener('mouseup', gpRelease);
      btn.addEventListener('mouseleave', gpRelease);
      btn.addEventListener('touchstart', function (e) { e.preventDefault(); gpPress(); }, { passive: false });
      btn.addEventListener('touchend',   function (e) { e.preventDefault(); gpRelease(); }, { passive: false });
      btn.addEventListener('touchcancel',function (e) { e.preventDefault(); gpRelease(); }, { passive: false });
    }

    var controls = document.createElement('div');
    controls.id = 'game-controls';

    // Left cluster: WASD d-pad (keyboard mode)
    var leftCluster = document.createElement('div');
    leftCluster.className = 'cluster-left';

    var btnUp    = document.createElement('button'); btnUp.className    = 'btn-up';    btnUp.textContent    = '▲'; attachButton(btnUp,    'w', 'KeyW');
    var btnLeft  = document.createElement('button'); btnLeft.className  = 'btn-left';  btnLeft.textContent  = '◀'; attachButton(btnLeft,  'a', 'KeyA');
    var btnDown  = document.createElement('button'); btnDown.className  = 'btn-down';  btnDown.textContent  = '▼'; attachButton(btnDown,  's', 'KeyS');
    var btnRight = document.createElement('button'); btnRight.className = 'btn-right'; btnRight.textContent = '▶'; attachButton(btnRight, 'd', 'KeyD');

    leftCluster.appendChild(btnUp);
    leftCluster.appendChild(btnLeft);
    leftCluster.appendChild(btnDown);
    leftCluster.appendChild(btnRight);

    // Right cluster: Pick up (E), Rotate (R), Esc (keyboard mode)
    var rightCluster = document.createElement('div');
    rightCluster.className = 'cluster-right';

    function makeActionButton(cls, key, code, label) {
      var btn = document.createElement('button');
      btn.className = 'btn-action ' + cls;
      btn.innerHTML = '<span class="btn-key">' + key.toUpperCase() + '</span><span class="btn-label">' + label + '</span>';
      attachButton(btn, key, code);
      return btn;
    }

    var btnPickup = makeActionButton('btn-pickup', 'e', 'KeyE', 'Pick');
    var btnRotate = makeActionButton('btn-rotate', 'r', 'KeyR', 'Rot');
    var btnEsc    = document.createElement('button'); btnEsc.className = 'btn-esc'; btnEsc.textContent = 'Esc'; attachButton(btnEsc, 'Escape', 'Escape');

    rightCluster.appendChild(btnPickup);
    rightCluster.appendChild(btnRotate);
    rightCluster.appendChild(btnEsc);

    // Gamepad left cluster: simulated D-pad (indices 12↑ 13↓ 14← 15→,
    // matching the standard Gamepad API mapping LÖVE reads via dpup/
    // dpdown/dpleft/dpright).
    var gpLeftCluster = document.createElement('div');
    gpLeftCluster.className = 'cluster-gamepad-left';
    gpLeftCluster.style.display = 'none';

    var gpBtnUp    = document.createElement('button'); gpBtnUp.className    = 'btn-gp-up';    gpBtnUp.textContent    = '▲'; attachGamepadButton(gpBtnUp,    12);
    var gpBtnLeft  = document.createElement('button'); gpBtnLeft.className  = 'btn-gp-left';  gpBtnLeft.textContent  = '◀'; attachGamepadButton(gpBtnLeft,  14);
    var gpBtnDown  = document.createElement('button'); gpBtnDown.className  = 'btn-gp-down';  gpBtnDown.textContent  = '▼'; attachGamepadButton(gpBtnDown,  13);
    var gpBtnRight = document.createElement('button'); gpBtnRight.className = 'btn-gp-right'; gpBtnRight.textContent = '▶'; attachGamepadButton(gpBtnRight, 15);

    gpLeftCluster.appendChild(gpBtnUp);
    gpLeftCluster.appendChild(gpBtnLeft);
    gpLeftCluster.appendChild(gpBtnDown);
    gpLeftCluster.appendChild(gpBtnRight);

    // Gamepad right cluster: A (index 0) = interact/pickup-drop, X (index 2)
    // = rotate — matches game/player.lua's gamepad_buttons mapping.
    var gpRightCluster = document.createElement('div');
    gpRightCluster.className = 'cluster-gamepad-right';
    gpRightCluster.style.display = 'none';

    var gpBtnA = document.createElement('button'); gpBtnA.className = 'btn-gp-a'; gpBtnA.textContent = 'A'; attachGamepadButton(gpBtnA, 0);
    var gpBtnX = document.createElement('button'); gpBtnX.className = 'btn-gp-x'; gpBtnX.textContent = 'X'; attachGamepadButton(gpBtnX, 2);

    gpRightCluster.appendChild(gpBtnA);
    gpRightCluster.appendChild(gpBtnX);

    // Mode toggle: switch the on-screen controls between firing keyboard
    // events and driving the fake gamepad, so controller support can be
    // smoke-tested in a browser with no physical controller attached.
    var currentMode = 'keyboard';
    var toggleBtn = document.createElement('button');
    toggleBtn.className = 'btn-toggle';
    toggleBtn.textContent = '⌨';
    toggleBtn.addEventListener('click', function () {
      if (currentMode === 'keyboard') {
        window.__fakeGamepad.connected = true;
        window.__fakeGamepad.timestamp = performance.now();
        var connectEv = new Event('gamepadconnected');
        connectEv.gamepad = window.__fakeGamepad;
        window.dispatchEvent(connectEv);

        leftCluster.style.display = 'none';
        rightCluster.style.display = 'none';
        gpLeftCluster.style.display = '';
        gpRightCluster.style.display = '';
        toggleBtn.textContent = '🎮';
        currentMode = 'gamepad';
      } else {
        window.__fakeGamepad.connected = false;
        var disconnectEv = new Event('gamepaddisconnected');
        disconnectEv.gamepad = window.__fakeGamepad;
        window.dispatchEvent(disconnectEv);

        gpLeftCluster.style.display = 'none';
        gpRightCluster.style.display = 'none';
        leftCluster.style.display = '';
        rightCluster.style.display = '';
        toggleBtn.textContent = '⌨';
        currentMode = 'keyboard';
      }
    });

    controls.appendChild(leftCluster);
    controls.appendChild(toggleBtn);
    controls.appendChild(rightCluster);
    controls.appendChild(gpLeftCluster);
    controls.appendChild(gpRightCluster);
    document.body.appendChild(controls);

    // --- SAVES: uncomment the block below if your game uses lua/core/save.lua ---
    // var saveControls = document.createElement('div');
    // saveControls.id = 'save-controls';
    // saveControls.style.cssText = 'display:flex;justify-content:center;padding:8px 12px;background:rgba(0,0,0,0.5);width:100%;box-sizing:border-box;';
    //
    // var btnClearSave = document.createElement('button');
    // btnClearSave.textContent = 'Clear All Data';
    // btnClearSave.style.cssText = 'padding:6px 16px;font-size:13px;background:rgba(180,40,40,0.5);border:1px solid rgba(255,80,80,0.5);border-radius:8px;color:white;cursor:pointer;';
    // btnClearSave.addEventListener('click', function () {
    //   if (!confirm('Delete your save? This cannot be undone.')) return;
    //   var savePath = '/home/web_user/love/' + (window.GAME_NAME || 'game') + '/save.dat';
    //   try {
    //     if (typeof Module !== 'undefined' && Module['FS_unlink']) {
    //       Module['FS_unlink'](savePath);
    //       if (Module['FS_syncfs']) {
    //         Module['FS_syncfs'](false, function (err) { location.reload(); });
    //       } else { location.reload(); }
    //     } else { alert('Game not loaded yet.'); }
    //   } catch (e) {
    //     if (Module['FS_syncfs']) { Module['FS_syncfs'](false, function () { location.reload(); }); }
    //     else { location.reload(); }
    //   }
    // });
    // saveControls.appendChild(btnClearSave);
    // document.body.appendChild(saveControls);
    // --- end SAVES ---
  });
}());
