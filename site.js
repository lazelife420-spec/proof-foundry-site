// site.js — interactive behavior only.
// The site shell (header, footer, product cards, status strips) is generated
// at build time from site-manifest.json. This file only handles the mobile
// navigation toggle and small affordances. Navigation works without it.

(function () {
  "use strict";

  function initNavToggle() {
    var header = document.querySelector(".site-header");
    var toggle = document.querySelector(".nav-toggle");
    if (!header || !toggle) return;

    function setOpen(open) {
      header.classList.toggle("nav-open", open);
      toggle.setAttribute("aria-expanded", open ? "true" : "false");
    }

    toggle.addEventListener("click", function () {
      setOpen(!header.classList.contains("nav-open"));
    });

    // Close after following any panel link, including the CTA (which now lives
    // inside the dropdown on mobile). Matters for same-page anchor jumps.
    header.addEventListener("click", function (e) {
      if (e.target.closest(".nav-panel a")) setOpen(false);
    });

    // Close on Escape
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape") setOpen(false);
    });

    // Close when the menu is open and a click lands outside the header
    document.addEventListener("click", function (e) {
      if (header.classList.contains("nav-open") && !e.target.closest(".site-header")) {
        setOpen(false);
      }
    });

    // Reset state when growing back to desktop
    var mql = window.matchMedia("(min-width: 901px)");
    mql.addEventListener("change", function (e) {
      if (e.matches) setOpen(false);
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initNavToggle);
  } else {
    initNavToggle();
  }
})();
