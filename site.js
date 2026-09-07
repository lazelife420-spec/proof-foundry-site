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

  function initSha256Copy() {
    var blocks = document.querySelectorAll(".sha256-block");
    if (!blocks.length) return;

    blocks.forEach(function (block) {
      var btn = block.querySelector(".sha256-copy");
      if (!btn) return;
      btn.addEventListener("click", function () {
        var value = block.getAttribute("data-sha256");
        if (!value) return;
        try {
          navigator.clipboard.writeText(value).then(function () {
            var original = btn.textContent;
            btn.textContent = "Copied";
            btn.classList.add("copied");
            setTimeout(function () {
              btn.textContent = original;
              btn.classList.remove("copied");
            }, 1500);
          });
        } catch (err) {
          // Fallback: select the code text
          var code = block.querySelector(".sha256-value");
          if (code) {
            var range = document.createRange();
            range.selectNode(code);
            window.getSelection().removeAllRanges();
            window.getSelection().addRange(range);
          }
        }
      });
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", function () {
      initNavToggle();
      initSha256Copy();
    });
  } else {
    initNavToggle();
    initSha256Copy();
  }
})();
