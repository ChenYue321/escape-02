/* ESCAPE_02 — small progressive enhancements only. */
(function () {
  "use strict";

  /* ---------- Local node clock ---------- */
  var clock = document.getElementById("clock");
  if (clock) {
    var pad = function (n) { return n < 10 ? "0" + n : String(n); };
    var tick = function () {
      var d = new Date();
      clock.textContent = pad(d.getHours()) + ":" + pad(d.getMinutes()) + ":" + pad(d.getSeconds());
      clock.setAttribute("datetime", d.toISOString());
    };
    tick();
    setInterval(tick, 1000);
  }

  /* ---------- Navigation ---------- */
  var nav = document.getElementById("nav");
  var toggle = document.getElementById("nav-toggle");
  var links = document.getElementById("nav-links");

  var setNavOpen = function (open) {
    if (!nav || !toggle) return;
    nav.classList.toggle("is-open", open);
    toggle.setAttribute("aria-expanded", open ? "true" : "false");
  };

  if (toggle) {
    toggle.addEventListener("click", function () {
      setNavOpen(!nav.classList.contains("is-open"));
    });
  }

  if (links) {
    links.addEventListener("click", function (event) {
      if (event.target.closest("a")) setNavOpen(false);
    });
  }

  document.addEventListener("keydown", function (event) {
    if (event.key === "Escape") setNavOpen(false);
  });

  window.addEventListener("resize", function () {
    if (window.innerWidth > 860) setNavOpen(false);
  });

  var onScroll = function () {
    if (nav) nav.classList.toggle("is-scrolled", window.scrollY > 24);
  };
  onScroll();
  window.addEventListener("scroll", onScroll, { passive: true });

  /* ---------- Reveal on scroll ---------- */
  var revealItems = Array.prototype.slice.call(document.querySelectorAll(".reveal"));

  if ("IntersectionObserver" in window && revealItems.length) {
    var revealObserver = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-in");
            revealObserver.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.1, rootMargin: "0px 0px -6% 0px" }
    );
    revealItems.forEach(function (item) { revealObserver.observe(item); });
  } else {
    revealItems.forEach(function (item) { item.classList.add("is-in"); });
  }

  /* ---------- Lightbox ---------- */
  var dialog = document.getElementById("lightbox");
  var lightboxImg = document.getElementById("lightbox-img");
  var lightboxCap = document.getElementById("lightbox-cap");
  var closeBtn = document.getElementById("lightbox-close");
  var prevBtn = document.getElementById("lightbox-prev");
  var nextBtn = document.getElementById("lightbox-next");
  var shots = Array.prototype.slice.call(document.querySelectorAll(".shot__btn"));
  var current = 0;
  var lastFocus = null;

  if (dialog && lightboxImg && shots.length && typeof dialog.showModal === "function") {
    var show = function (index) {
      current = (index + shots.length) % shots.length;
      var button = shots[current];
      var img = button.querySelector("img");
      if (!img) return;

      lightboxImg.src = img.currentSrc || img.src;
      lightboxImg.alt = img.alt || "";
      lightboxCap.textContent = button.getAttribute("data-caption") || img.alt || "";

      if (!dialog.open) {
        lastFocus = document.activeElement;
        dialog.showModal();
        document.body.classList.add("lightbox-open");
        if (closeBtn) closeBtn.focus();
      }
    };

    var hide = function () {
      if (dialog.open) dialog.close();
    };

    shots.forEach(function (button, index) {
      button.addEventListener("click", function () { show(index); });
    });

    if (closeBtn) closeBtn.addEventListener("click", hide);
    if (prevBtn) prevBtn.addEventListener("click", function () { show(current - 1); });
    if (nextBtn) nextBtn.addEventListener("click", function () { show(current + 1); });

    dialog.addEventListener("click", function (event) {
      if (event.target === dialog) hide();
    });

    dialog.addEventListener("keydown", function (event) {
      if (event.key === "ArrowLeft") {
        event.preventDefault();
        show(current - 1);
      } else if (event.key === "ArrowRight") {
        event.preventDefault();
        show(current + 1);
      }
    });

    dialog.addEventListener("close", function () {
      document.body.classList.remove("lightbox-open");
      lightboxImg.removeAttribute("src");
      if (lastFocus && typeof lastFocus.focus === "function") lastFocus.focus();
    });
  }
})();
