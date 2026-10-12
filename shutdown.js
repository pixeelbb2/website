/*
  shutdown.js — the fake [X] button (POWER-CUT gag)
  =====================================================================
  Shared by every page (it used to be copy-pasted into each file).

  WHAT HAPPENS
  Clicking [X] in the title bar:
    1. AUDIO   an HV static snap -> collapsing-picture whine (2600->70Hz)
               -> glass thump, all synthesized live with the Web Audio
               API. No audio files to host.
    2. VISION  the window wobbles (.kill-wobble), collapses into a
               bright horizontal line (#killLine), then into a glowing
               dot that dies (#killDot), then the screen goes black.
    3. REPLY   #shutOverlay fades in with "AND NOW WHAT?" and a
               "[ CLICK TO REOPEN ]" link that restores the page.

  TIMELINE (milliseconds from the click)
    0   wobble starts + sound
  140   wobble off, window -> thin line, #killLine on
  320   #killLine off, window -> dot, #killDot on
  560   #shutOverlay shows

  REQUIRED MARKUP (every page ships this)
    .vintage-page            the window that gets "killed"
    .title-bar .x-btn        the button this binds to
    #killLine / #killDot     collapsing-light FX (optional; safe to omit)
    #shutOverlay             "AND NOW WHAT?" overlay (optional)
    #shutReopen              "reopen" link inside the overlay (optional)

  Self-guarding: if the window or button is missing the script simply
  does nothing, so it is safe to include on any future page.
  =====================================================================
*/
(function () {
  var page = document.querySelector('.vintage-page');
  var overlay = document.getElementById('shutOverlay');
  var line = document.getElementById('killLine');
  var dot = document.getElementById('killDot');
  var btn = document.querySelector('.title-bar .x-btn');
  var reopen = document.getElementById('shutReopen');
  if (!page || !overlay || !btn) return;

  function playUnplug() {
    try {
      var AC = window.AudioContext || window.webkitAudioContext;
      var ctx = new AC();
      var t = ctx.currentTime;

      // 1. HV static snap: short filtered noise burst
      var len = Math.floor(ctx.sampleRate * 0.09);
      var buf = ctx.createBuffer(1, len, ctx.sampleRate);
      var d = buf.getChannelData(0);
      for (var i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, 2);
      var noise = ctx.createBufferSource();
      noise.buffer = buf;
      var hp = ctx.createBiquadFilter();
      hp.type = 'highpass';
      hp.frequency.value = 1200;
      var ng = ctx.createGain();
      ng.gain.setValueAtTime(0.5, t);
      ng.gain.exponentialRampToValueAtTime(0.0001, t + 0.1);
      noise.connect(hp);
      hp.connect(ng);
      ng.connect(ctx.destination);
      noise.start(t);

      // 2. collapsing-picture whine: 2600 -> 70 Hz
      var osc = ctx.createOscillator();
      var gain = ctx.createGain();
      osc.type = 'sawtooth';
      osc.frequency.setValueAtTime(2600, t + 0.02);
      osc.frequency.exponentialRampToValueAtTime(70, t + 0.38);
      gain.gain.setValueAtTime(0.0001, t);
      gain.gain.exponentialRampToValueAtTime(0.14, t + 0.05);
      gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.4);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(t);
      osc.stop(t + 0.42);

      // 3. glass thump as the dot dies
      var th = ctx.createOscillator();
      var tg = ctx.createGain();
      th.type = 'sine';
      th.frequency.setValueAtTime(160, t + 0.34);
      th.frequency.exponentialRampToValueAtTime(45, t + 0.5);
      tg.gain.setValueAtTime(0.0001, t + 0.34);
      tg.gain.exponentialRampToValueAtTime(0.25, t + 0.37);
      tg.gain.exponentialRampToValueAtTime(0.0001, t + 0.55);
      th.connect(tg);
      tg.connect(ctx.destination);
      th.start(t + 0.34);
      th.stop(t + 0.6);

      setTimeout(function () { try { ctx.close(); } catch (e) { } }, 800);
    } catch (e) { }
  }

  btn.addEventListener('click', function () {
    playUnplug();
    // Collapse around the middle of the SCREEN (where the light lives),
    // not the middle of the (much taller) page.
    try {
      var r = page.getBoundingClientRect();
      var yPct = ((window.innerHeight / 2 - r.top) / r.height) * 100;
      yPct = Math.max(0, Math.min(100, yPct));
      page.style.transformOrigin = '50% ' + yPct + '%';
    } catch (e) { }
    page.classList.add('kill-wobble');
    setTimeout(function () {
      page.classList.remove('kill-wobble');
      page.classList.add('kill-line');
      if (line) line.classList.add('on');
    }, 140);
    setTimeout(function () {
      if (line) line.classList.remove('on');
      page.classList.add('kill-dot');
      if (dot) dot.classList.add('on');
    }, 320);
    setTimeout(function () { overlay.classList.add('show'); }, 560);
  });

  if (reopen) reopen.addEventListener('click', function (e) {
    e.preventDefault();
    overlay.classList.remove('show');
    if (line) line.classList.remove('on');
    if (dot) dot.classList.remove('on');
    page.classList.remove('kill-dot');
    page.classList.remove('kill-line');
    page.classList.remove('kill-wobble');
    page.style.transformOrigin = '';
    window.scrollTo(0, 0);
  });
})();
