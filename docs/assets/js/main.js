(function () {
  "use strict";

  /* Falling data in the background. */
  (function initDataRain() {
    var layer = document.getElementById("data-rain");
    if (!layer || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    var glyphs = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#%&@$?!/\\<>*+=[]{}";
    var colors = ["#58c46e", "#377f49", "#8fe3a0"];
    var count = window.innerWidth <= 760 ? 8 : 20;
    var columns = [];
    var fragment = document.createDocumentFragment();

    function randomChar() {
      return glyphs.charAt(Math.floor(Math.random() * glyphs.length));
    }

    function randomString(length) {
      var text = "";
      for (var i = 0; i < length; i += 1) text += randomChar();
      return text;
    }

    for (var i = 0; i < count; i += 1) {
      var column = document.createElement("span");
      var duration = 8 + Math.random() * 12;

      column.className = "data-rain__col";
      column.textContent = randomString(20 + Math.floor(Math.random() * 26));
      column.style.left = (((i + 0.15 + Math.random() * 0.7) / count) * 100).toFixed(2) + "%";
      column.style.animationDuration = duration.toFixed(2) + "s";
      column.style.animationDelay = (-Math.random() * duration).toFixed(2) + "s";
      column.style.fontSize = (11.5 + Math.random() * 3.5).toFixed(1) + "px";
      column.style.opacity = (0.12 + Math.random() * 0.2).toFixed(2);
      column.style.color = colors[i % colors.length];

      fragment.appendChild(column);
      columns.push(column);
    }

    layer.appendChild(fragment);

    window.setInterval(function () {
      if (document.hidden || !columns.length) return;
      var column = columns[Math.floor(Math.random() * columns.length)];
      var text = column.textContent;
      var at = Math.floor(Math.random() * text.length);
      column.textContent = text.slice(0, at) + randomChar() + text.slice(at + 1);
      if (Math.random() < 0.15) {
        column.style.opacity = (0.1 + Math.random() * 0.2).toFixed(2);
      }
    }, 800);
  })();

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
