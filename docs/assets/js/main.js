(function () {
  "use strict";

  /* Dismiss the notice box. */
  var notice = document.getElementById("notice");
  var noticeClose = document.getElementById("notice-close");
  if (notice && noticeClose) {
    noticeClose.addEventListener("click", function () {
      notice.remove();
    });
  }

  /* Cycle [DISABLE] -> garble -> [ENABLE] -> garble. */
  var state = document.getElementById("state-word");
  if (!state) return;

  var glyphs = "ABCDEFGHJKLMNPQRSTUVWXYZ0123456789#%&@$?!/\\<>*";
  var phases = [
    { text: "[DISABLE]", cls: "is-disable", ms: 1000 },
    { garble: true, cls: "is-garble", ms: 500 },
    { text: "[ENABLE]", cls: "is-enable", ms: 1000 },
    { garble: true, cls: "is-garble", ms: 500 }
  ];
  var index = 0;

  function makeGarble() {
    var output = "[";
    for (var i = 0; i < 7; i += 1) {
      output += glyphs.charAt(Math.floor(Math.random() * glyphs.length));
    }
    return output + "]";
  }

  function step() {
    var phase = phases[index];
    state.textContent = phase.garble ? makeGarble() : phase.text;
    state.classList.remove("is-disable", "is-enable", "is-garble");
    state.classList.add(phase.cls);
    index = (index + 1) % phases.length;
    window.setTimeout(step, phase.ms);
  }

  step();
})();
