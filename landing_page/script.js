(function () {
  "use strict";

  /* ---------- Barre de navigation : état au défilement ---------- */
  var navWrap = document.querySelector(".navbar-wrap");
  function onScroll() {
    navWrap.classList.toggle("scrolled", window.scrollY > 24);
  }
  onScroll();
  window.addEventListener("scroll", onScroll, { passive: true });

  /* ---------- Menu mobile ---------- */
  var toggle = document.getElementById("nav-toggle");
  var links = document.getElementById("nav-links");

  function setMenu(open) {
    links.classList.toggle("open", open);
    toggle.setAttribute("aria-expanded", String(open));
    toggle.setAttribute("aria-label", open ? "Fermer le menu" : "Ouvrir le menu");
  }

  toggle.addEventListener("click", function () {
    setMenu(toggle.getAttribute("aria-expanded") !== "true");
  });

  links.addEventListener("click", function (e) {
    if (e.target.closest("a")) setMenu(false);
  });

  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape") setMenu(false);
  });

  /* ---------- Onglets de l'aperçu ---------- */
  // Sur mobile, le texte de chaque module s'affiche sous le téléphone
  document.querySelectorAll(".tab-item").forEach(function (item) {
    var btn = item.querySelector(".tab-btn");
    var panel = document.getElementById(btn.getAttribute("data-tab"));
    var inner = item.querySelector(".tab-body-inner");
    if (!panel || !inner) return;
    var text = document.createElement("div");
    text.className = "panel-text";
    text.setAttribute("style", item.getAttribute("style") || "");
    text.innerHTML = inner.innerHTML;
    panel.appendChild(text);
  });

  var tabBtns = Array.prototype.slice.call(document.querySelectorAll(".tab-btn"));
  var panels = Array.prototype.slice.call(document.querySelectorAll(".tab-content"));

  function activate(btn, focus) {
    var targetId = btn.getAttribute("data-tab");

    tabBtns.forEach(function (b) {
      var on = b === btn;
      b.setAttribute("aria-selected", String(on));
      b.setAttribute("tabindex", on ? "0" : "-1");
      b.parentElement.classList.toggle("active", on);
    });

    panels.forEach(function (p) {
      p.classList.toggle("active", p.id === targetId);
    });

    if (focus) btn.focus();
    if (btn.parentElement.scrollIntoView) {
      btn.parentElement.scrollIntoView({ inline: "center", block: "nearest", behavior: "smooth" });
    }
  }

  tabBtns.forEach(function (btn, i) {
    btn.addEventListener("click", function () {
      activate(btn, false);
    });

    btn.addEventListener("keydown", function (e) {
      var next = null;
      if (e.key === "ArrowDown" || e.key === "ArrowRight") next = tabBtns[(i + 1) % tabBtns.length];
      if (e.key === "ArrowUp" || e.key === "ArrowLeft") next = tabBtns[(i - 1 + tabBtns.length) % tabBtns.length];
      if (e.key === "Home") next = tabBtns[0];
      if (e.key === "End") next = tabBtns[tabBtns.length - 1];
      if (next) {
        e.preventDefault();
        activate(next, true);
      }
    });
  });

  /* ---------- FAQ : une seule réponse ouverte à la fois ---------- */
  var faqItems = Array.prototype.slice.call(document.querySelectorAll(".faq-item"));

  faqItems.forEach(function (item) {
    var q = item.querySelector(".faq-question");
    q.addEventListener("click", function () {
      var willOpen = !item.classList.contains("open");
      faqItems.forEach(function (other) {
        other.classList.remove("open");
        other.querySelector(".faq-question").setAttribute("aria-expanded", "false");
      });
      if (willOpen) {
        item.classList.add("open");
        q.setAttribute("aria-expanded", "true");
      }
    });
  });

  /* ---------- Sommaire de la page légale ---------- */
  var tocLinks = Array.prototype.slice.call(document.querySelectorAll(".legal-toc a"));
  if (tocLinks.length && "IntersectionObserver" in window) {
    var map = {};
    tocLinks.forEach(function (a) { map[a.getAttribute("href").slice(1)] = a; });
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        if (en.isIntersecting) {
          tocLinks.forEach(function (a) { a.classList.remove("active"); });
          var a = map[en.target.id];
          if (a) a.classList.add("active");
        }
      });
    }, { rootMargin: "-30% 0px -60% 0px" });
    Object.keys(map).forEach(function (id) {
      var el = document.getElementById(id);
      if (el) io.observe(el);
    });
  }
})();
