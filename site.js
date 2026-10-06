// site.js — interactive behavior only.
// The site shell (header, footer, product cards, status strips) is generated
// at build time from site-manifest.json. This file handles navigation, the real-image gallery and small affordances. Navigation works without it.

(function () {
  "use strict";

  // One motion policy for every page. Content never starts hidden, and the
  // device's accessibility settings take precedence over a saved preference.
  function initMotion() {
    var root = document.documentElement;
    var reduced = matchMedia("(prefers-reduced-motion: reduce)");
    var forced = matchMedia("(forced-colors: active)");
    var fine = matchMedia("(hover: hover) and (pointer: fine)");
    var preference = "on", active = false, progressFrame = 0, tiltFrame = 0;
    try { if (localStorage.getItem("pf-motion") === "off") preference = "off"; } catch (_) {}
    var button = document.createElement("button");
    button.type = "button";
    button.className = "motion-toggle";
    var progress = document.createElement("div");
    progress.className = "pf-reading-progress";
    progress.setAttribute("aria-hidden", "true");
    var plate = document.querySelector(".ledger-plate");
    var scene = document.querySelector(".ledger-plate-scene");
    var running = new Set();

    function resetPlate() {
      cancelAnimationFrame(tiltFrame);
      if (plate) {
        plate.style.removeProperty("--pf-tilt-x");
        plate.style.removeProperty("--pf-tilt-y");
      }
    }
    function updateProgress() {
      progressFrame = 0;
      var distance = document.documentElement.scrollHeight - innerHeight;
      var value = distance > 0 ? Math.min(1, Math.max(0, scrollY / distance)) : 0;
      progress.style.transform = "scaleX(" + value + ")";
    }
    function scheduleProgress() {
      if (active && !progressFrame) progressFrame = requestAnimationFrame(updateProgress);
    }
    function apply() {
      active = !reduced.matches && !forced.matches && preference === "on";
      root.dataset.motion = active ? "on" : "off";
      button.textContent = reduced.matches ? "Reduced motion" : forced.matches ? "Motion off" : "Motion " + (active ? "on" : "off");
      button.setAttribute("aria-pressed", String(active));
      button.setAttribute("aria-label", reduced.matches || forced.matches ? "Website motion follows your device accessibility setting" : "Website motion");
      button.disabled = reduced.matches || forced.matches;
      progress.hidden = !active;
      if (!active) {
        cancelAnimationFrame(progressFrame);
        progressFrame = 0;
        resetPlate();
        running.forEach(animation => animation.cancel());
        // Includes the existing product screen-change enhancement.
        document.getAnimations?.().forEach(animation => animation.cancel());
      } else scheduleProgress();
    }
    document.querySelector(".footer-bottom")?.append(button);
    document.body.append(progress);
    button.addEventListener("click", function () {
      preference = preference === "on" ? "off" : "on";
      try { localStorage.setItem("pf-motion", preference); } catch (_) {}
      apply();
    });
    reduced.addEventListener("change", apply);
    forced.addEventListener("change", apply);
    fine.addEventListener("change", resetPlate);
    addEventListener("storage", function (event) {
      if (event.key === "pf-motion" || event.key === null) {
        preference = event.newValue === "off" ? "off" : "on";
        apply();
      }
    });
    addEventListener("scroll", scheduleProgress, { passive: true });
    addEventListener("resize", scheduleProgress, { passive: true });
    if (window.ResizeObserver) new ResizeObserver(scheduleProgress).observe(document.body);
    document.addEventListener("visibilitychange", function () {
      if (document.hidden) resetPlate();
      else scheduleProgress();
    });
    apply();

    if (scene && plate) {
      scene.addEventListener("pointermove", function (event) {
        if (!active || !fine.matches || event.pointerType !== "mouse") return;
        var bounds = scene.getBoundingClientRect();
        var x = Math.min(.5, Math.max(-.5, (event.clientX - bounds.left) / bounds.width - .5));
        var y = Math.min(.5, Math.max(-.5, (event.clientY - bounds.top) / bounds.height - .5));
        cancelAnimationFrame(tiltFrame);
        tiltFrame = requestAnimationFrame(function () {
          if (!active) return;
          plate.style.setProperty("--pf-tilt-x", (-y * 4).toFixed(2) + "deg");
          plate.style.setProperty("--pf-tilt-y", (x * 5).toFixed(2) + "deg");
        });
      });
      scene.addEventListener("pointerleave", resetPlate);
      scene.addEventListener("pointercancel", resetPlate);
    }

    // Animate only small headings and cards arriving below the first viewport.
    // Never animate a whole release record, a focused control, or a hash target.
    if (window.IntersectionObserver && Element.prototype.animate) {
      var arrivals = new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          arrivals.unobserve(entry.target);
          if (!active || entry.target.contains(document.activeElement) || location.hash) return;
          var animation = entry.target.animate([
            { transform: "translateY(10px)", opacity: .88 },
            { transform: "translateY(0)", opacity: 1 }
          ], { duration: 420, easing: "cubic-bezier(.2,.7,.3,1)" });
          running.add(animation);
          animation.finished.then(() => running.delete(animation), () => running.delete(animation));
        });
      }, { threshold: .08 });
      document.querySelectorAll(".ledger-section-label,.ledger-instrument,.section-heading,.section-head,.experience-heading,.product-card,.about-nav-card,.tf-section > h2").forEach(function (element) {
        if (element.getBoundingClientRect().top >= innerHeight) arrivals.observe(element);
      });
      document.addEventListener("focusin", function (event) {
        running.forEach(function (animation) {
          if (animation.effect.target.contains(event.target)) animation.cancel();
        });
      });
      addEventListener("hashchange", function () { running.forEach(animation => animation.cancel()); });
    }
  }

  function initScreenshots() {
    const links = [...document.querySelectorAll('[data-screenshot]')];
    if (!links.length || !window.HTMLDialogElement) return;
    const make = (tag, className, text) => { const e = document.createElement(tag); if (className) e.className = className; if (text) e.textContent = text; return e; };
    const button = (label, className) => { const e = make('button', className, label); e.type = 'button'; return e; };
    const dialog = make('dialog', 'image-viewer gallery-viewer');
    dialog.setAttribute('aria-label', 'Product screenshot gallery');
    const header = make('header', 'gallery-header');
    const identity = make('div');
    identity.append(make('span', 'gallery-kicker', 'THE PROOF FOUNDRY / INSIDE THE SOFTWARE'), make('h2', '', document.querySelector('.product-identity > span')?.textContent || 'From the foundry'));
    const close = button('Close', 'gallery-close'); close.setAttribute('aria-label', 'Close screenshot');
    header.append(identity,close);
    const canvas = make('div','gallery-canvas'); canvas.tabIndex = 0; canvas.setAttribute('aria-label','Screenshot. Zoom to inspect details.');
    const full = make('img','gallery-full'); canvas.append(full);
    const information = make('div','gallery-information');
    const title = make('strong'), caption = make('p'); caption.setAttribute('aria-live','polite');
    const text = make('div'); text.append(title,caption);
    const count = make('span','gallery-count'); information.append(text,count);
    const actions = make('div','gallery-actions');
    const previous = button('Previous','gallery-previous'), next = button('Next','gallery-next'), zoom = button('Zoom to 100%','gallery-zoom');
    zoom.setAttribute('aria-pressed','false');
    const original = make('a','gallery-original','Open original'); original.target='_blank'; original.rel='noopener';
    actions.append(previous,next,zoom,original);
    const rail = make('div','gallery-thumbnails'); rail.setAttribute('role','group'); rail.setAttribute('aria-label','Choose a screenshot');
    const status = make('p','gallery-status'); status.setAttribute('role','status');
    dialog.append(header,canvas,information,actions,rail,status); document.body.append(dialog);
    let gallery = [], active = 0, request = 0, zoomed = false;
    function collect(href) {
      const items = [], seen = new Set();
      const add = item => { item.original = new URL(item.original, document.baseURI).href; if (!seen.has(item.original)) { seen.add(item.original); items.push(item); } };
      const template = document.getElementById('product-gallery');
      template?.content.querySelectorAll('a').forEach(a => add({original:a.href,thumb:a.dataset.thumb,preview:a.dataset.preview,width:Number(a.dataset.width),height:Number(a.dataset.height),title:a.dataset.title,caption:a.dataset.caption}));
      links.forEach(a => {
        if (template && a.href !== href) return;
        const i = a.querySelector('img'); if (!i) return;
        add({original:a.href,thumb:i.currentSrc || i.src,preview:i.src,width:i.width,height:i.height,title:i.alt,caption:a.closest('figure')?.querySelector('figcaption')?.textContent || 'Actual product screenshot.'});
      });
      return items;
    }
    async function show(index) {
      const ticket = ++request, shot = gallery[index];
      status.textContent='Loading screenshot…'; canvas.setAttribute('aria-busy','true');
      const candidate = new Image(); candidate.src = zoomed ? shot.original : shot.preview;
      try {
        await candidate.decode(); if (ticket !== request || !dialog.open) return;
        active=index; full.src=candidate.src; full.alt=shot.caption; full.width=shot.width; full.height=shot.height;
        title.textContent=shot.title; caption.textContent=shot.caption; count.textContent=`${active+1} / ${gallery.length}`; original.href=shot.original;
        canvas.classList.toggle('is-zoomed',zoomed); zoom.textContent=zoomed?'Fit to screen':'Zoom to 100%'; zoom.setAttribute('aria-pressed',String(zoomed));
        if (zoomed) { full.style.width=`${candidate.naturalWidth}px`; full.style.height='auto'; canvas.scrollLeft=Math.max(0,(candidate.naturalWidth-canvas.clientWidth)/2); canvas.scrollTop=0; }
        else { full.style.width='';full.style.height='';canvas.scrollLeft=0;canvas.scrollTop=0; }
        [...rail.children].forEach((b,i)=>b.setAttribute('aria-pressed',String(i===active)));
        const selected=rail.children[active]; if (selected) rail.scrollLeft=Math.max(0,selected.offsetLeft-rail.offsetLeft-(rail.clientWidth-selected.offsetWidth)/2);
        previous.disabled=next.disabled=gallery.length<2; status.textContent='';
      } catch (_) { if (ticket===request) { original.href=shot.original; status.textContent='This screenshot could not load. Try another screen or open the original.'; } }
      finally { if (ticket===request) canvas.removeAttribute('aria-busy'); }
    }
    function open(href) {
      gallery=collect(href); active=Math.max(0,gallery.findIndex(s=>s.original===href)); zoomed=false; rail.replaceChildren();
      gallery.forEach((shot,index)=>{ const b=button('','gallery-thumbnail'); b.setAttribute('aria-label',`View ${shot.title}`); b.setAttribute('aria-pressed',String(index===active)); const i=make('img');i.src=shot.thumb;i.alt='';i.loading='lazy';const label=make('span','',shot.title);b.append(i,label);b.addEventListener('click',()=>show(index));rail.append(b); });
      rail.hidden=gallery.length<2; full.removeAttribute('src'); title.textContent='';caption.textContent='';count.textContent='';original.href=gallery[active].original;
      dialog.showModal();close.focus();show(active);
    }
    links.forEach(link=>link.addEventListener('click',event=>{ if(event.ctrlKey||event.metaKey||event.shiftKey||event.altKey)return;event.preventDefault();open(link.href); }));
    document.querySelectorAll('[data-gallery-open]').forEach(b=>{b.hidden=false;b.addEventListener('click',()=>open(links[0].href));});
    close.addEventListener('click',()=>dialog.close());
    dialog.addEventListener('close',()=>{++request;canvas.removeAttribute('aria-busy');});
    const move = direction => show((active+direction+gallery.length)%gallery.length);
    previous.addEventListener('click',()=>move(-1)); next.addEventListener('click',()=>move(1));
    zoom.addEventListener('click',()=>{zoomed=!zoomed;show(active);});
    dialog.addEventListener('keydown',event=>{if(!zoomed&&['ArrowLeft','ArrowRight'].includes(event.key)){event.preventDefault();move(event.key==='ArrowRight'?1:-1);}});
    let pointer=null;
    canvas.addEventListener('pointerdown',e=>{pointer={x:e.clientX,y:e.clientY,left:canvas.scrollLeft,top:canvas.scrollTop,type:e.pointerType};if(zoomed&&e.pointerType==='mouse'){e.preventDefault();canvas.setPointerCapture(e.pointerId);canvas.classList.add('is-dragging');}});
    canvas.addEventListener('pointermove',e=>{if(pointer&&zoomed&&pointer.type==='mouse'){canvas.scrollLeft=pointer.left+pointer.x-e.clientX;canvas.scrollTop=pointer.top+pointer.y-e.clientY;}});
    canvas.addEventListener('pointerup',e=>{if(pointer&&!zoomed&&pointer.type==='touch'&&Math.abs(e.clientX-pointer.x)>70&&Math.abs(e.clientY-pointer.y)<50)move(e.clientX<pointer.x?1:-1);pointer=null;canvas.classList.remove('is-dragging');});
    canvas.addEventListener('pointercancel',()=>{pointer=null;canvas.classList.remove('is-dragging');});
  }

  function revealDeepLink() {
    if (!location.hash) return;
    var id;
    try { id = decodeURIComponent(location.hash.slice(1)); } catch (error) { return; }
    var target = document.getElementById(id);
    if (!target) return;
    // Evidence can sit inside more than one disclosure. Open the full chain,
    // including the proof section's own record, before scrolling to it.
    var changed = false;
    var parent = target;
    while (parent) {
      if (parent.tagName === "DETAILS" && !parent.open) { parent.open = true; changed = true; }
      parent = parent.parentElement;
    }
    var record = id === "proof" ? target.querySelector("details") : null;
    if (record && !record.open) { record.open = true; changed = true; }
    if (changed) target.scrollIntoView({ block: "start", behavior: "instant" });
  }
  window.addEventListener("hashchange", revealDeepLink);

  function initProductWayfinding() {
    var nav = document.querySelector(".pf-product-navigation");
    if (!nav) return;
    var links = Array.from(nav.querySelectorAll("[data-product-section]"));
    var pending = false;
    function indicate() {
      pending = false;
      var current = links[0];
      links.forEach(function (link) {
        var section = document.getElementById(link.dataset.productSection);
        if (section && section.getClientRects().length && section.getBoundingClientRect().top <= nav.offsetHeight + 90) current = link;
      });
      links.forEach(function (link) {
        if (link === current) link.setAttribute("aria-current", "location");
        else link.removeAttribute("aria-current");
      });
    }
    function schedule() { if (!pending) { pending = true; requestAnimationFrame(indicate); } }
    window.addEventListener("scroll", schedule, { passive: true });
    window.addEventListener("resize", schedule, { passive: true });
    document.addEventListener("toggle", schedule, true);
    indicate();
  }

  function initWorkbench() {
    var workbench = document.querySelector("[data-workbench]");
    if (!workbench) return;
    var panels = Array.from(workbench.querySelectorAll("[data-workbench-product]"));
    var tabs = workbench.querySelector(".pf-workbench-tabs");
    if (!panels.length || !tabs) return;
    tabs.setAttribute("role", "tablist");
    var buttons = panels.map(function (panel) {
      var button = document.createElement("button");
      button.type = "button";
      button.id = "tab-" + panel.id;
      button.setAttribute("role", "tab");
      button.setAttribute("aria-controls", panel.id);
      button.textContent = panel.dataset.workbenchName;
      panel.setAttribute("role", "tabpanel");
      panel.setAttribute("aria-labelledby", button.id);
      panel.tabIndex = 0;
      tabs.append(button);
      return button;
    });
    function select(index, focus) {
      panels.forEach(function (panel, i) { panel.hidden = i !== index; });
      buttons.forEach(function (button, i) { button.setAttribute("aria-selected", String(i === index)); button.tabIndex = i === index ? 0 : -1; });
      if (focus) { buttons[index].focus({ preventScroll: true }); buttons[index].scrollIntoView({ block: "nearest", inline: "nearest", behavior: "instant" }); }
    }
    buttons.forEach(function (button, index) {
      button.addEventListener("click", function () { select(index, false); });
      button.addEventListener("keydown", function (event) {
        var next = event.key === "ArrowRight" ? (index + 1) % buttons.length : event.key === "ArrowLeft" ? (index + buttons.length - 1) % buttons.length : event.key === "Home" ? 0 : event.key === "End" ? buttons.length - 1 : -1;
        if (next !== -1) { event.preventDefault(); select(next, true); }
      });
    });
    tabs.hidden = false;
    select(0, false);
  }

  function initSupportDraft() {
    var draft = document.querySelector("[data-support-draft]");
    var output = document.getElementById("diagnostic-template");
    if (!draft || !output) return;
    var product = draft.querySelector('[name="product"]');
    var record = draft.querySelector("[data-support-record]");
    var fields = [["version","Version"],["os","Operating system / Android version"],["device","Device model (if relevant)"],["install","Install type"],["source","Where the file came from"],["hash","Did the published SHA-256 match?"],["happened","What happened"],["steps","Steps to reproduce"],["expected","Expected behavior"],["actual","Actual behavior"],["error","Exact sanitized error text"],["attachment","Optional screenshot/log"]];
    function update() {
      var option = product.options[product.selectedIndex];
      var lines = ["Product: " + (product.value ? option.textContent : "")];
      fields.forEach(function (field) { var value = draft.querySelector('[name="' + field[0] + '"]').value.trim(); lines.push(field[1] + ":" + (value.includes("\n") ? "\n" : " ") + value); });
      output.value = lines.join("\n");
      record.hidden = !product.value;
      if (product.value) record.setAttribute("href", option.dataset.record);
      else record.removeAttribute("href");
    }
    var requested = new URLSearchParams(location.search).get("product");
    if (Array.from(product.options).some(function (option) { return option.value === requested; })) product.value = requested;
    draft.addEventListener("input", update);
    draft.addEventListener("change", update);
    draft.querySelector("[data-support-reset]").addEventListener("click", function () {
      draft.querySelectorAll("input,textarea,select").forEach(function (field) { field.value = ""; });
      update(); product.focus();
    });
    draft.hidden = false;
    update();
  }

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
      if (e.key === "Escape" && header.classList.contains("nav-open")) {
        setOpen(false);
        toggle.focus();
      }
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
        function selectChecksum() {
          var code = block.querySelector(".sha256-value");
          if (!code) return;
          var range = document.createRange();
          range.selectNodeContents(code);
          window.getSelection().removeAllRanges();
          window.getSelection().addRange(range);
          btn.textContent = "Text selected";
        }
        try {
          navigator.clipboard.writeText(value).then(function () {
            var original = btn.textContent;
            btn.textContent = "Copied";
            btn.classList.add("copied");
            setTimeout(function () {
              btn.textContent = original;
              btn.classList.remove("copied");
            }, 1500);
          }).catch(selectChecksum);
        } catch (err) {
          selectChecksum();
        }
      });
    });
  }

  function initTemplateCopy() {
    var buttons = document.querySelectorAll("[data-copy-target]");
    if (!buttons.length) return;
    buttons.forEach(function (btn) {
      btn.addEventListener("click", function () {
        var targetId = btn.getAttribute("data-copy-target");
        var target = document.getElementById(targetId);
        if (!target) return;
        var text = target.value || target.textContent;
        function selectText() {
          if (target.select) target.select();
          btn.textContent = "Text selected";
        }
        try {
          navigator.clipboard.writeText(text).then(function () {
            var original = btn.textContent;
            btn.textContent = "Template copied!";
            btn.classList.add("copied");
            setTimeout(function () {
              btn.textContent = original;
              btn.classList.remove("copied");
            }, 2000);
          }).catch(selectText);
        } catch (err) {
          selectText();
        }
      });
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", function () {
      initNavToggle();
      initSha256Copy();
      initTemplateCopy();
      initScreenshots();
      initWorkbench();
      initProductWayfinding();
      initSupportDraft();
      revealDeepLink();
      initMotion();
    });
  } else {
    initNavToggle();
    initSha256Copy();
    initTemplateCopy();
    initScreenshots();
    initWorkbench();
    initProductWayfinding();
    initSupportDraft();
    revealDeepLink();
    initMotion();
  }
})();
