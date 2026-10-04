// site.js — interactive behavior only.
// The site shell (header, footer, product cards, status strips) is generated
// at build time from site-manifest.json. This file handles navigation, the real-image gallery and small affordances. Navigation works without it.

(function () {
  "use strict";

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
    var details = target.closest("details");
    if (!details && id === "proof") details = target.querySelector("details");
    if (details && !details.open) {
      details.open = true;
      target.scrollIntoView({ block: "start" });
    }
  }
  window.addEventListener("hashchange", revealDeepLink);

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
      revealDeepLink();
    });
  } else {
    initNavToggle();
    initSha256Copy();
    initTemplateCopy();
    initScreenshots();
    revealDeepLink();
  }
})();
