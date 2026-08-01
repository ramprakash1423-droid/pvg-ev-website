(function () {
  const headerMount = document.querySelector("[data-site-header]");
  const footerMount = document.querySelector("[data-site-footer]");
  const currentYear = new Date().getFullYear();

  const navItems = [
    { name: "Home", path: "index.html", key: "home" },
    { name: "Mobile Charging Station", path: "mobile-charging-station.html", key: "station" },
    {
      name: "Solutions",
      path: "solutions.html",
      key: "solutions",
      children: [
        ["Mobile EV Charging", "solutions.html#mobile-ev-charging"],
        ["Fleet & Depot Charging", "solutions.html#fleet-depot-charging"],
        ["Commercial EV Charging", "solutions.html#commercial-charging"],
        ["Apartment Charging", "solutions.html#apartment-charging"],
        ["Maintenance & Support", "solutions.html#maintenance-support"]
      ]
    },
    { name: "Fleet Solutions", path: "fleet-solutions.html", key: "fleet" },
    { name: "About PVG-EV", path: "about-pvg-ev.html", key: "about" },
    { name: "PVG-EV × Setrans", path: "collaboration.html", key: "collaboration" },
    { name: "Pilot Programme", path: "pilot-programme.html", key: "pilot" },
    { name: "Insights", path: "insights.html", key: "insights" },
    { name: "Contact", path: "contact.html", key: "contact" }
  ];

  const footerLinks = [
    ["Request Charging", "request-charging.html"],
    ["Mobile Charging Station", "mobile-charging-station.html"],
    ["Solutions", "solutions.html"],
    ["Fleet Solutions", "fleet-solutions.html"],
    ["PVG-EV × Setrans", "collaboration.html"],
    ["Pilot Programme", "pilot-programme.html"],
    ["Insights", "insights.html"],
    ["Contact", "contact.html"]
  ];

  const policyLinks = [
    ["Privacy Policy", "privacy-policy.html"],
    ["Terms and Conditions", "terms-and-conditions.html"],
    ["Cookie Policy", "cookie-policy.html"],
    ["Sitemap", "sitemap.xml"]
  ];

  const normalizeRoot = (root) => {
    if (!root || root === ".") return "";
    return root.replace(/\/?$/, "/");
  };

  const url = (root, path) => `${normalizeRoot(root)}${path}`;

  const renderHeader = () => {
    if (!headerMount) return;
    const root = headerMount.dataset.root || "";
    const active = headerMount.dataset.active || "home";
    const navLink = (item) => {
      if (!item.children) {
        return `<a class="nav-link ${active === item.key ? "is-active" : ""}" href="${url(root, item.path)}" ${active === item.key ? 'aria-current="page"' : ""}>${item.name}</a>`;
      }

      const menuId = `nav-submenu-${item.key}`;
      return `
        <div class="nav-dropdown ${active === item.key ? "is-active" : ""}" data-dropdown>
          <button class="nav-link dropdown-toggle" type="button" aria-expanded="false" aria-controls="${menuId}" data-dropdown-toggle ${active === item.key ? 'aria-current="page"' : ""}>
            ${item.name}<span class="dropdown-caret" aria-hidden="true"></span>
          </button>
          <div class="dropdown-menu" id="${menuId}" data-dropdown-menu>
            <a class="dropdown-link dropdown-link-main" href="${url(root, item.path)}">Solutions Overview</a>
            ${item.children.map(([name, path]) => `<a class="dropdown-link" href="${url(root, path)}">${name}</a>`).join("")}
          </div>
        </div>
      `;
    };

    headerMount.innerHTML = `
      <header class="site-header" data-header>
        <nav class="nav-shell nav-shell-client" aria-label="Primary navigation">
          <a class="brand" href="${url(root, "index.html")}" aria-label="PVG-EV home">
            <img class="brand-logo-real nav-logo-real" src="${url(root, "public/assets/pvg-ev/branding/logo-primary.svg")}" alt="PVG-EV — Endless Power, Endless Journey" width="620" height="180" decoding="async">
            <span class="sr-only">PVG-EV — Prime Ventures Global</span>
          </a>
          <button class="nav-toggle" type="button" aria-label="Open menu" aria-expanded="false" aria-controls="site-menu" data-nav-toggle>
            <span></span><span></span><span></span>
          </button>
          <div class="nav-menu nav-menu-client" id="site-menu" data-nav-menu>
            ${navItems.map(navLink).join("")}
            <a class="nav-link mobile-contact-link mobile-request-link ${active === "request" ? "is-active" : ""}" href="${url(root, "request-charging.html")}" data-event="mobile_nav_request_charging">Request Mobile Charging</a>
          </div>
          <div class="nav-actions" aria-label="Primary actions">
            <a class="nav-cta nav-cta-request ${active === "request" ? "is-active" : ""}" href="${url(root, "request-charging.html")}" data-event="nav_request_charging">Request Mobile Charging</a>
            <a class="nav-cta ${active === "contact" ? "is-active" : ""}" href="${url(root, "contact.html")}" data-event="nav_contact">Contact</a>
          </div>
        </nav>
      </header>
    `;
  };

  const renderFooter = () => {
    if (!footerMount) return;
    const root = footerMount.dataset.root || "";
    const footerSection = (title, id, content) => `
      <div class="footer-column footer-accordion" data-footer-accordion>
        <button class="footer-accordion-trigger" type="button" aria-expanded="true" aria-controls="${id}" data-footer-accordion-trigger>
          <span>${title}</span>
          <span class="footer-chevron" aria-hidden="true"></span>
        </button>
        <div class="footer-accordion-panel" id="${id}" data-footer-accordion-panel>${content}</div>
      </div>
    `;

    footerMount.innerHTML = `
      <footer class="site-footer">
        <div class="footer-shell footer-shell-client">
          <div class="footer-brand">
            <a class="brand" href="${url(root, "index.html")}" aria-label="PVG-EV home">
              <img class="brand-logo-real footer-logo-real" src="${url(root, "public/assets/pvg-ev/branding/logo-white.svg")}" alt="PVG-EV Prime Ventures Global logo" width="620" height="180" loading="lazy" decoding="async">
              <span class="sr-only">PVG-EV Prime Ventures Global</span>
            </a>
            <p>PVG-EV is an electric-mobility initiative of Prime Ventures Global. Mobile Charging Station technology is developed by Setrans and introduced in Tamil Nadu through the PVG-EV collaboration.</p>
            <div class="footer-social" aria-label="PVG-EV social channels pending verification">
              <span class="footer-social-item is-disabled"><span class="social-icon social-icon-linkedin" aria-hidden="true"></span><span>LinkedIn</span></span>
              <span class="footer-social-item is-disabled"><span class="social-icon social-icon-youtube" aria-hidden="true"></span><span>YouTube</span></span>
              <span class="footer-social-item is-disabled"><span class="social-icon social-icon-facebook" aria-hidden="true"></span><span>Facebook</span></span>
              <span class="footer-social-item is-disabled"><span class="social-icon social-icon-instagram" aria-hidden="true"></span><span>Instagram</span></span>
            </div>
            <details class="footer-note-details">
              <summary>Service disclaimer</summary>
              <p class="footer-note">Product specifications, charging availability, service coverage and launch dates are subject to testing, certification, operational readiness and local deployment conditions. Images may include development-stage or representative product configurations.</p>
            </details>
          </div>
          ${footerSection("Website", "footer-website-links", footerLinks.map(([name, path]) => `<a href="${url(root, path)}">${name}</a>`).join(""))}
          ${footerSection("Solutions", "footer-solution-links", `
            <a href="${url(root, "solutions.html#mobile-ev-charging")}">Mobile EV Charging</a>
            <a href="${url(root, "solutions.html#commercial-charging")}">Commercial EV Charging</a>
            <a href="${url(root, "solutions.html#apartment-charging")}">Apartment Charging</a>
            <a href="${url(root, "solutions.html#maintenance-support")}">Maintenance and Support</a>
          `)}
          ${footerSection("Contact", "footer-contact-links", `
            <a href="${url(root, "request-charging.html")}">Request Charging</a>
            <a href="${url(root, "contact.html")}">Contact PVG-EV</a>
            <a href="${url(root, "pilot-programme.html#pilot-form")}">Join the Chennai Pilot</a>
            <a href="${url(root, "contact.html#contact-form")}">Request a Consultation</a>
            <a href="https://wa.me/919751083000" target="_blank" rel="noopener">WhatsApp: +91 97510 83000</a>
            <span class="footer-static">Chennai pilot market: Tamil Nadu, India</span>
          `)}
          ${footerSection("Legal", "footer-legal-links", policyLinks.map(([name, path]) => `<a href="${url(root, path)}">${name}</a>`).join(""))}
          <div class="footer-column footer-newsletter">
            <h2>EV Updates</h2>
            <p>Get pilot notes, charging explainers and fleet-readiness resources.</p>
            <form data-footer-newsletter novalidate>
              <label class="sr-only" for="footer-newsletter-email">Email address</label>
              <input id="footer-newsletter-email" type="email" name="email" placeholder="Email address" autocomplete="email" required>
              <button type="submit" aria-label="Subscribe to PVG-EV updates">Subscribe</button>
              <span class="footer-newsletter-status" data-footer-newsletter-status aria-live="polite"></span>
            </form>
          </div>
        </div>
        <div class="footer-bottom">
          <span>PVG-EV by Prime Ventures Global</span>
          <span>Copyright ${currentYear}. All rights reserved.</span>
        </div>
      </footer>
      <div class="cookie-consent" data-cookie-banner hidden>
        <p>PVG-EV uses essential cookies and may use analytics cookies after launch to understand website performance and enquiry conversions.</p>
        <button class="button button-primary" type="button" data-cookie-accept>Accept</button>
      </div>
    `;
  };

  const renderQuickEnquiry = () => {
    const root = headerMount?.dataset.root || footerMount?.dataset.root || "";
    if (document.querySelector("[data-quick-enquiry]")) return;
    if (document.querySelector(".station-product-page")) return;
    const widget = document.createElement("div");
    widget.className = "quick-enquiry sticky-request-cta";
    widget.setAttribute("data-quick-enquiry", "");
    widget.innerHTML = `
      <a class="quick-enquiry-button quick-enquiry-link" href="${url(root, "request-charging.html")}" data-event="sticky_request_mobile_charging">
        <span>Request Mobile Charging</span>
      </a>
      <nav class="mobile-action-bar" aria-label="Mobile quick actions">
        <a href="${url(root, "request-charging.html")}" data-event="mobile_request_charging">Request Charging</a>
      </nav>
    `;
    document.body.appendChild(widget);
  };

  const initFooterAccordions = () => {
    const accordions = Array.from(document.querySelectorAll("[data-footer-accordion]"));
    if (!accordions.length) return;
    const mobileQuery = window.matchMedia("(max-width: 640px)");

    const setFooterPanel = (accordion, open, persist = true) => {
      const trigger = accordion.querySelector("[data-footer-accordion-trigger]");
      const panel = accordion.querySelector("[data-footer-accordion-panel]");
      if (!trigger || !panel) return;
      trigger.setAttribute("aria-expanded", String(open));
      panel.hidden = !open;
      if (persist) accordion.dataset.footerOpen = String(open);
    };

    const syncFooterMode = () => {
      accordions.forEach((accordion) => {
        if (!mobileQuery.matches) {
          setFooterPanel(accordion, true, false);
          return;
        }
        setFooterPanel(accordion, accordion.dataset.footerOpen === "true");
      });
    };

    accordions.forEach((accordion) => {
      accordion.dataset.footerOpen = "false";
      accordion.querySelector("[data-footer-accordion-trigger]")?.addEventListener("click", () => {
        if (!mobileQuery.matches) return;
        setFooterPanel(accordion, accordion.dataset.footerOpen !== "true");
      });
    });

    if (mobileQuery.addEventListener) mobileQuery.addEventListener("change", syncFooterMode);
    else mobileQuery.addListener?.(syncFooterMode);
    syncFooterMode();
  };

  renderHeader();
  renderFooter();
  renderQuickEnquiry();
  initFooterAccordions();

  const header = document.querySelector("[data-header]");
  const navToggle = document.querySelector("[data-nav-toggle]");
  const navMenu = document.querySelector("[data-nav-menu]");
  const stickyCta = document.querySelector("[data-quick-enquiry]");
  const reduceMotion = window.matchMedia?.("(prefers-reduced-motion: reduce)").matches ?? false;
  let lastMenuFocus = null;
  document.documentElement.classList.add("animations-ready");

  const trackPvgEvent = (eventName, detail = {}) => {
    if (!eventName) return;
    window.dataLayer = window.dataLayer || [];
    window.dataLayer.push({ event: eventName, ...detail });
    window.dispatchEvent(new CustomEvent("pvg:analytics", { detail: { event: eventName, ...detail } }));
  };

  const setMenu = (open) => {
    if (!navToggle || !navMenu) return;
    const wasOpen = navMenu.classList.contains("is-open");
    if (open && !wasOpen) lastMenuFocus = document.activeElement instanceof HTMLElement ? document.activeElement : navToggle;
    navToggle.setAttribute("aria-expanded", String(open));
    navToggle.setAttribute("aria-label", open ? "Close menu" : "Open menu");
    navMenu.classList.toggle("is-open", open);
    document.body.classList.toggle("menu-open", open);
    document.documentElement.classList.toggle("menu-open", open);
    document.body.style.overflow = open ? "hidden" : "";
    if (!open) {
      closeDropdowns();
      if (wasOpen) window.requestAnimationFrame(() => (lastMenuFocus || navToggle).focus?.({ preventScroll: true }));
    }
  };

  navToggle?.addEventListener("click", () => {
    setMenu(navToggle.getAttribute("aria-expanded") !== "true");
  });

  document.querySelectorAll(".nav-menu a").forEach((link) => {
    link.addEventListener("click", () => setMenu(false));
  });

  const closeDropdowns = () => {
    document.querySelectorAll("[data-dropdown]").forEach((dropdown) => {
      dropdown.classList.remove("is-open");
      dropdown.querySelector("[data-dropdown-toggle]")?.setAttribute("aria-expanded", "false");
    });
  };

  document.querySelectorAll("[data-dropdown-toggle]").forEach((button) => {
    button.addEventListener("click", (event) => {
      event.stopPropagation();
      const dropdown = button.closest("[data-dropdown]");
      const nextOpen = !dropdown?.classList.contains("is-open");
      closeDropdowns();
      dropdown?.classList.toggle("is-open", nextOpen);
      button.setAttribute("aria-expanded", String(nextOpen));
    });
  });

  document.querySelectorAll("[data-dropdown-menu] a").forEach((link) => {
    link.addEventListener("click", () => {
      closeDropdowns();
      setMenu(false);
    });
  });

  document.addEventListener("click", (event) => {
    if (!event.target.closest("[data-dropdown]")) closeDropdowns();
    if (navMenu?.classList.contains("is-open") && !event.target.closest("[data-header]")) {
      setMenu(false);
    }
  });

  window.addEventListener("keydown", (event) => {
    if (event.key === "Tab" && navMenu?.classList.contains("is-open")) {
      const focusable = Array.from(navMenu.querySelectorAll("a[href], button:not([disabled])"))
        .filter((element) => element instanceof HTMLElement && element.offsetParent !== null);
      if (focusable.length) {
        const first = focusable[0];
        const last = focusable[focusable.length - 1];
        if (event.shiftKey && document.activeElement === first) {
          event.preventDefault();
          last.focus();
        } else if (!event.shiftKey && document.activeElement === last) {
          event.preventDefault();
          first.focus();
        }
      }
    }
    if (event.key === "Escape") {
      setMenu(false);
      closeDropdowns();
      setQuickPanel(false);
    }
  });

  window.addEventListener("pageshow", () => setMenu(false));
  window.addEventListener("popstate", () => setMenu(false));

  const quickPanel = document.querySelector("[data-quick-panel]");
  const quickToggles = document.querySelectorAll("[data-quick-toggle], [data-quick-toggle-mobile]");
  const setQuickPanel = (open) => {
    quickToggles.forEach((toggle) => toggle.setAttribute("aria-expanded", String(open)));
    if (quickPanel) quickPanel.hidden = !open;
  };

  quickToggles.forEach((toggle) => {
    toggle.addEventListener("click", () => {
      const isOpen = toggle.getAttribute("aria-expanded") === "true";
      setQuickPanel(!isOpen);
      if (!isOpen) trackPvgEvent("quick_enquiry_open", { source: toggle.dataset.quickToggleMobile === "" ? "mobile" : "desktop" });
    });
  });

  document.addEventListener("click", (event) => {
    if (!event.target.closest("[data-quick-enquiry]")) setQuickPanel(false);
  });

  document.querySelectorAll("[data-event]").forEach((item) => {
    item.addEventListener("click", () => trackPvgEvent(item.dataset.event, {
      label: item.textContent.trim(),
      path: window.location.pathname
    }));
  });

  const syncHeader = () => {
    header?.classList.remove("is-scrolled");
    const hero = document.querySelector(".home-ref-hero, .compact-home-hero, .station-hero-v3, .pilot-hero-v2, .station-product-hero, .request-hero, .page-hero, .hero");
    const trigger = hero ? hero.offsetTop + hero.offsetHeight * .72 : 180;
    const activeElement = document.activeElement;
    const hasFormFocus = Boolean(activeElement?.matches?.("input, textarea, select, [contenteditable='true']"));
    const cookieVisible = Boolean(document.querySelector("[data-cookie-banner]:not([hidden])"));
    const blockingSections = Array.from(document.querySelectorAll(".compact-final-cta, [data-major-cta], .site-footer, [data-contact-form], [data-pilot-form], [data-request-form], .request-form-card"));
    const isBlockedBySection = blockingSections.some((section) => {
      const rect = section.getBoundingClientRect();
      return rect.top < window.innerHeight - 70 && rect.bottom > 70;
    });
    const visibleSubmit = Array.from(document.querySelectorAll(".form-submit, [data-request-submit]")).some((button) => {
      const rect = button.getBoundingClientRect();
      return rect.top < window.innerHeight - 80 && rect.bottom > 70;
    });
    stickyCta?.classList.toggle("is-visible", window.scrollY > trigger && !isBlockedBySection && !hasFormFocus && !visibleSubmit && !cookieVisible && !document.body.classList.contains("menu-open"));
  };

  syncHeader();
  window.addEventListener("scroll", syncHeader, { passive: true });
  window.addEventListener("resize", syncHeader);
  document.addEventListener("focusin", syncHeader);
  document.addEventListener("focusout", () => window.setTimeout(syncHeader, 0));

  const revealItems = document.querySelectorAll(".reveal");
  const revealVisibleItems = () => {
    revealItems.forEach((item) => {
      const rect = item.getBoundingClientRect();
      if (rect.top < window.innerHeight * 1.08 && rect.bottom > -80) {
        item.classList.add("is-visible");
      }
    });
  };

  if ("IntersectionObserver" in window && !reduceMotion) {
    const revealObserver = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          revealObserver.unobserve(entry.target);
        }
      });
    }, { threshold: 0.14 });
    revealItems.forEach((item) => revealObserver.observe(item));
  } else {
    revealItems.forEach((item) => item.classList.add("is-visible"));
  }
  window.requestAnimationFrame(revealVisibleItems);
  window.setTimeout(revealVisibleItems, 180);
  window.setTimeout(revealVisibleItems, 700);

  const animatedScenes = document.querySelectorAll(".station-operational-visual, .station-process-visual, .station-scenario-visual, .pilot-map-visual, [data-charging-journey]");
  if (animatedScenes.length && "IntersectionObserver" in window && !reduceMotion) {
    const animationObserver = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        entry.target.classList.toggle("is-paused", !entry.isIntersecting);
      });
    }, { threshold: 0.08 });
    animatedScenes.forEach((scene) => animationObserver.observe(scene));
  }

  const counterItems = Array.from(document.querySelectorAll("[data-count]"));
  const animateCounter = (item) => {
    if (item.dataset.counted === "true") return;
    item.dataset.counted = "true";
    const target = Number(item.dataset.count || 0);
    const suffix = item.dataset.suffix || "";
    if (reduceMotion || !target) {
      item.textContent = `${target}${suffix}`;
      return;
    }
    const start = performance.now();
    const duration = 900;
    const tick = (time) => {
      const progress = Math.min((time - start) / duration, 1);
      const eased = 1 - Math.pow(1 - progress, 3);
      item.textContent = `${Math.round(target * eased)}${suffix}`;
      if (progress < 1) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  };

  if (counterItems.length) {
    if ("IntersectionObserver" in window && !reduceMotion) {
      const counterObserver = new IntersectionObserver((entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            animateCounter(entry.target);
            counterObserver.unobserve(entry.target);
          }
        });
      }, { threshold: 0.5 });
      counterItems.forEach((item) => counterObserver.observe(item));
    } else {
      counterItems.forEach(animateCounter);
    }
  }

  const insightSearchInputs = Array.from(document.querySelectorAll("[data-insight-search]"));
  const insightSearch = insightSearchInputs[0];
  const insightCards = Array.from(document.querySelectorAll("[data-insight-card]"));
  const insightChips = Array.from(document.querySelectorAll("[data-filter-chip]"));
  const insightEmpty = document.querySelector("[data-insights-empty]");
  const insightClear = document.querySelector("[data-insight-clear]");
  const insightSearchClearButtons = Array.from(document.querySelectorAll("[data-insight-search-clear]"));
  const insightCount = document.querySelector("[data-insight-count]");
  const insightLoadMore = document.querySelector("[data-insight-load-more]");
  let activeInsightFilter = "all";
  let insightVisibleLimit = window.matchMedia?.("(max-width: 640px)").matches ? 5 : 9;
  let insightLastKey = "";
  const allowedInsightFilters = new Set([
    "all",
    "mobile",
    "commercial",
    "apartment",
    "pilot",
    "chennai",
    "sustainability",
    "business",
    ...insightChips.map((chip) => chip.dataset.filter || "all")
  ]);
  const insightFilterLabels = {
    all: "all categories",
    "ev-industry": "EV industry",
    "tamil-nadu": "Tamil Nadu",
    "future-mobility": "future mobility"
  };
  const getInsightPageSize = () => window.matchMedia?.("(max-width: 640px)").matches ? 5 : 9;
  const escapeHtml = (value) => String(value).replace(/[&<>"']/g, (char) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "\"": "&quot;",
    "'": "&#39;"
  })[char]);
  const escapeRegExp = (value) => String(value).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const highlightInsightText = (node, query) => {
    if (!node) return;
    if (!node.dataset.originalText) node.dataset.originalText = node.textContent || "";
    const original = node.dataset.originalText;
    if (!query) {
      node.textContent = original;
      return;
    }
    const pattern = new RegExp(`(${escapeRegExp(query)})`, "ig");
    node.innerHTML = escapeHtml(original).replace(pattern, "<mark>$1</mark>");
  };
  let insightSearchTimer = 0;

  const syncInsightUrl = () => {
    if (!insightCards.length || !("URLSearchParams" in window) || !window.history?.replaceState) return;
    const params = new URLSearchParams(window.location.search);
    const query = (insightSearch?.value || "").trim();

    if (query) params.set("q", query);
    else params.delete("q");

    if (activeInsightFilter && activeInsightFilter !== "all") params.set("category", activeInsightFilter);
    else params.delete("category");

    const nextQuery = params.toString();
    const nextUrl = `${window.location.pathname}${nextQuery ? `?${nextQuery}` : ""}${window.location.hash || ""}`;
    window.history.replaceState(null, "", nextUrl);
  };

  const syncInsightChips = () => {
    insightChips.forEach((chip) => {
      const isActive = (chip.dataset.filter || "all") === activeInsightFilter;
      chip.classList.toggle("is-active", isActive);
      chip.setAttribute("aria-pressed", String(isActive));
    });
  };

  const setActiveInsightFilter = (filter, options = {}) => {
    activeInsightFilter = allowedInsightFilters.has(filter) ? filter : "all";
    syncInsightChips();
    applyInsightFilters({ ...options, resetLimit: true });
  };

  const syncInsightSearchInputs = (value, source) => {
    insightSearchInputs.forEach((input) => {
      if (input !== source) input.value = value;
    });
  };

  const applyInsightFilters = (options = {}) => {
    if (!insightCards.length) return;
    const query = (insightSearch?.value || "").trim().toLowerCase();
    const stateKey = `${activeInsightFilter}|${query}`;
    if (options.resetLimit || stateKey !== insightLastKey) {
      insightVisibleLimit = getInsightPageSize();
      insightLastKey = stateKey;
    }
    const matchingCards = [];

    insightCards.forEach((card, index) => {
      const categories = (card.dataset.category || "").toLowerCase().split(/\s+/);
      const searchable = `${card.dataset.title || ""} ${card.dataset.summary || ""} ${card.textContent || ""}`.toLowerCase();
      const matchesFilter = activeInsightFilter === "all" || categories.includes(activeInsightFilter);
      const matchesSearch = !query || searchable.includes(query);
      const isVisible = matchesFilter && matchesSearch;
      if (isVisible) matchingCards.push(card);
      card.hidden = true;
      card.style.setProperty("--stagger-index", String(index % 6));
      highlightInsightText(card.querySelector("h3"), query);
      highlightInsightText(card.querySelector(".insights-card-body p"), query);
    });

    matchingCards.forEach((card, index) => {
      card.hidden = index >= insightVisibleLimit;
      card.classList.toggle("is-newly-visible", index >= insightVisibleLimit - getInsightPageSize());
    });

    const visibleCount = Math.min(matchingCards.length, insightVisibleLimit);
    if (insightEmpty) insightEmpty.hidden = matchingCards.length !== 0;
    if (insightCount) {
      const filterLabel = insightFilterLabels[activeInsightFilter] || `${activeInsightFilter.replace(/-/g, " ")} insights`;
      insightCount.textContent = `Showing ${visibleCount} of ${matchingCards.length} insights in ${filterLabel}`;
    }
    if (insightClear) {
      const hasActiveFilters = Boolean(query) || activeInsightFilter !== "all";
      insightClear.hidden = !hasActiveFilters;
    }
    insightSearchClearButtons.forEach((button) => {
      button.hidden = !query;
    });
    if (insightLoadMore) {
      insightLoadMore.hidden = matchingCards.length <= insightVisibleLimit;
      insightLoadMore.textContent = `Load More Insights (${Math.max(matchingCards.length - insightVisibleLimit, 0)} left)`;
    }
    if (options.updateUrl !== false) syncInsightUrl();
  };

  if (insightCards.length) {
    if ("URLSearchParams" in window) {
      const params = new URLSearchParams(window.location.search);
      const initialQuery = params.get("q") || "";
      const initialFilter = params.get("category") || "all";
      if (initialQuery) insightSearchInputs.forEach((input) => { input.value = initialQuery; });
      activeInsightFilter = allowedInsightFilters.has(initialFilter) ? initialFilter : "all";
    }

    insightSearchInputs.forEach((input) => {
      input.addEventListener("input", () => {
        syncInsightSearchInputs(input.value, input);
        window.clearTimeout(insightSearchTimer);
        insightSearchTimer = window.setTimeout(() => applyInsightFilters({ resetLimit: true }), 120);
      });
      input.addEventListener("keydown", (event) => {
        if (event.key === "Escape" && input.value) {
          input.value = "";
          syncInsightSearchInputs("", input);
          applyInsightFilters({ resetLimit: true });
        }
      });
    });
    insightChips.forEach((chip) => {
      chip.addEventListener("click", () => {
        setActiveInsightFilter(chip.dataset.filter || "all");
      });
    });
    insightClear?.addEventListener("click", () => {
      insightSearchInputs.forEach((input) => { input.value = ""; });
      setActiveInsightFilter("all");
      insightSearch?.focus({ preventScroll: true });
    });
    insightSearchClearButtons.forEach((button) => {
      button.addEventListener("click", () => {
        insightSearchInputs.forEach((input) => { input.value = ""; });
        applyInsightFilters({ resetLimit: true });
        insightSearch?.focus({ preventScroll: true });
      });
    });
    insightLoadMore?.addEventListener("click", () => {
      insightVisibleLimit += getInsightPageSize();
      applyInsightFilters({ updateUrl: false });
    });
    document.querySelectorAll("[data-tag-filter]").forEach((tag) => {
      tag.addEventListener("click", (event) => {
        event.preventDefault();
        const target = tag.dataset.tagFilter || "all";
        setActiveInsightFilter(target);
        document.querySelector("#latest-insights")?.scrollIntoView({ behavior: reduceMotion ? "auto" : "smooth", block: "start" });
        insightSearch?.focus({ preventScroll: true });
      });
    });
    window.addEventListener("resize", () => {
      insightVisibleLimit = Math.max(insightVisibleLimit, getInsightPageSize());
      applyInsightFilters({ updateUrl: false });
    });
    syncInsightChips();
    applyInsightFilters({ updateUrl: false });
  }

  document.querySelectorAll("[data-faq-toggle]").forEach((button) => {
    const panel = document.getElementById(button.getAttribute("aria-controls") || "");
    button.addEventListener("click", () => {
      const isOpen = button.getAttribute("aria-expanded") === "true";
      button.setAttribute("aria-expanded", String(!isOpen));
      if (panel) panel.hidden = isOpen;
    });
  });

  document.querySelectorAll("[data-footer-newsletter]").forEach((form) => {
    const input = form.querySelector("input[type='email']");
    const status = form.querySelector("[data-footer-newsletter-status]");
    form.addEventListener("submit", (event) => {
      event.preventDefault();
      const value = input?.value.trim() || "";
      const valid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
      if (!valid) {
        if (status) status.textContent = "Enter a valid email address.";
        input?.setAttribute("aria-invalid", "true");
        input?.focus();
        return;
      }
      input?.setAttribute("aria-invalid", "false");
      if (status) status.textContent = "Thank you. Updates will be shared after launch.";
      form.reset();
      trackPvgEvent("footer_newsletter_submit", { path: window.location.pathname });
    });
  });

  document.querySelectorAll("[data-contact-form]").forEach((form) => {
    const requirementSelect = form.querySelector("[data-requirement-select]");
    const categoryButtons = Array.from(document.querySelectorAll("[data-contact-category]"));
    const actionItems = Array.from(document.querySelectorAll("[data-contact-action]"));
    const conditionalGroups = Array.from(form.querySelectorAll("[data-conditional-group]"));
    const phoneInputs = Array.from(form.querySelectorAll("[data-phone-input]"));
    const successPanel = form.querySelector("[data-form-success]");
    const status = form.querySelector("[data-form-status]");
    let highlightTimer;

    const setFormHighlight = () => {
      window.clearTimeout(highlightTimer);
      form.classList.add("is-highlighted");
      highlightTimer = window.setTimeout(() => form.classList.remove("is-highlighted"), 1100);
    };

    const syncConditionalFields = (value) => {
      conditionalGroups.forEach((group) => {
        const isActive = group.dataset.conditionalGroup === value;
        group.hidden = !isActive;
        group.querySelectorAll("[data-conditional-field]").forEach((field) => {
          field.disabled = !isActive;
          if (!isActive) {
            field.classList.remove("is-invalid");
            field.removeAttribute("aria-invalid");
          }
        });
      });
    };

    const setRequirement = (value, options = {}) => {
      if (requirementSelect && value && Array.from(requirementSelect.options).some((option) => option.value === value || option.textContent === value)) {
        requirementSelect.value = value;
      }

      const selected = requirementSelect?.value || value || "";
      categoryButtons.forEach((button) => {
        const isActive = button.dataset.contactType === selected;
        button.classList.toggle("is-selected", isActive);
        button.setAttribute("aria-pressed", String(isActive));
      });
      actionItems.forEach((item) => {
        if (!item.classList.contains("contact-option-card")) return;
        const isActive = item.dataset.contactType === selected;
        item.classList.toggle("is-selected", isActive);
        item.setAttribute("aria-pressed", String(isActive));
      });
      syncConditionalFields(selected);

      if (options.focusForm) {
        form.scrollIntoView({ behavior: "smooth", block: "start" });
        setFormHighlight();
        requirementSelect?.focus({ preventScroll: true });
      }
    };

    categoryButtons.forEach((button) => {
      button.addEventListener("click", () => {
        setRequirement(button.dataset.contactType || "", { focusForm: true });
        if (status) status.textContent = "";
        if (successPanel) successPanel.hidden = true;
      });
    });

    actionItems.forEach((item) => {
      item.addEventListener("click", (event) => {
        const type = item.dataset.contactType;
        if (!type) return;
        event.preventDefault();
        setRequirement(type, { focusForm: true });
        if (status) status.textContent = "";
        if (successPanel) successPanel.hidden = true;
      });
    });

    requirementSelect?.addEventListener("change", () => {
      setRequirement(requirementSelect.value);
      if (successPanel) successPanel.hidden = true;
    });

    phoneInputs.forEach((input) => {
      input.addEventListener("focus", () => {
        if (!input.value.trim()) input.value = "+91 ";
      });
      input.addEventListener("input", () => {
        const digits = input.value.replace(/\D/g, "");
        const localDigits = digits.startsWith("91") ? digits.slice(2, 12) : digits.slice(0, 10);
        input.value = localDigits ? `+91 ${localDigits}` : "+91 ";
      });
    });

    form.querySelectorAll("[data-new-enquiry]").forEach((button) => {
      button.addEventListener("click", () => {
        form.reset();
        phoneInputs.forEach((input) => { input.value = "+91 "; });
        if (status) status.textContent = "";
        if (successPanel) successPanel.hidden = true;
        setRequirement("");
        setFormHighlight();
        form.querySelector("input, select, textarea")?.focus();
      });
    });

    form.addEventListener("reset", () => {
      window.setTimeout(() => {
        phoneInputs.forEach((input) => {
          if (!input.value.trim()) input.value = "+91 ";
        });
        setRequirement(requirementSelect?.value || "");
      }, 0);
    });

    setRequirement(requirementSelect?.value || "");
  });

  const forms = Array.from(document.querySelectorAll("[data-contact-form], [data-pilot-form]"));
  const defaultMessages = {
    name: "Please enter your name.",
    email: "Please enter a valid email address.",
    telephone: "Please enter a valid telephone number.",
    phone: "Please enter a valid telephone number.",
    message: "Please share a short message."
  };

  const setError = (field, message) => {
    const form = field.closest("form");
    const error = form?.querySelector(`[data-error-for="${field.name}"]`);
    field.classList.toggle("is-invalid", Boolean(message));
    field.setAttribute("aria-invalid", message ? "true" : "false");
    if (error) error.textContent = message || "";
  };

  const fieldLabel = (field) => {
    const form = field.closest("form");
    const label = form?.querySelector(`label[for="${field.id}"]`);
    return field.dataset.reviewLabel || label?.textContent?.replace("*", "").replace(/\((optional|default 1|approx\.)\)/gi, "").trim() || field.name;
  };

  const validateField = (field) => {
    if (field.disabled || field.type === "hidden") return true;
    const value = field.type === "checkbox" ? field.checked : field.value.trim();
    let error = "";

    if (field.required && (field.type === "checkbox" ? !field.checked : !value)) {
      error = field.type === "checkbox" ? "Please confirm this option." : `${fieldLabel(field)} is required.`;
    } else if (field.type === "email" && value && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) {
      error = defaultMessages.email;
    } else if (field.type === "tel" && value) {
      const digits = value.replace(/\D/g, "");
      const isIndianMobile = /^([6-9]\d{9}|91[6-9]\d{9})$/.test(digits);
      error = isIndianMobile ? "" : "Please enter a valid Indian mobile number.";
    } else if (field.name === "message" && value && value.length < 12) {
      error = "Please add a little more detail.";
    }

    setError(field, error);
    return !error;
  };

  forms.forEach((form) => {
    const fields = Array.from(form.querySelectorAll("input, select, textarea"));
    const status = form.querySelector("[data-form-status]");
    const submitButton = form.querySelector(".form-submit, [type='submit']");
    const successPanel = form.querySelector("[data-form-success]");
    const originalSubmitText = submitButton?.innerHTML || submitButton?.textContent || "";
    let submitted = false;

    fields.forEach((field) => {
      field.addEventListener("blur", () => validateField(field));
      field.addEventListener("input", () => {
        if (field.classList.contains("is-invalid")) validateField(field);
      });
      field.addEventListener("change", () => {
        if (field.classList.contains("is-invalid")) validateField(field);
      });
    });

    form.addEventListener("submit", (event) => {
      event.preventDefault();
      if (submitted) return;
      const isValid = fields.map(validateField).every(Boolean);

      if (!isValid) {
        if (status) {
          status.textContent = "Please fix the highlighted fields and submit again.";
          status.classList.remove("is-success");
          status.classList.add("is-error");
        }
        form.querySelector(".is-invalid")?.focus();
        return;
      }

      if (navigator.onLine === false) {
        if (status) {
          status.textContent = "The browser appears to be offline. Please reconnect and submit again.";
          status.classList.remove("is-success");
          status.classList.add("is-error");
        }
        return;
      }

      submitted = true;
      if (submitButton) {
        submitButton.disabled = true;
        submitButton.classList.add("is-loading");
        submitButton.setAttribute("aria-busy", "true");
        submitButton.innerHTML = "<span class=\"pvg-line-icon icon-loading\" aria-hidden=\"true\"></span> Submitting...";
      }
      if (successPanel) successPanel.hidden = true;
      if (status) {
        status.textContent = "Submitting your details...";
        status.classList.remove("is-error", "is-success");
      }

      window.setTimeout(() => {
        if (status) {
          status.textContent = form.dataset.staticContactForm === "true"
            ? "Thank you. Your enquiry has been received."
            : form.dataset.pilotForm === "true"
            ? "Thank you. Your Chennai pilot interest has been recorded for review."
            : "Thank you. Your PVG-EV enquiry has been received.";
          status.classList.remove("is-error");
          status.classList.add("is-success");
        }
        if (successPanel) successPanel.hidden = false;
        fields.forEach((field) => setError(field, ""));
        // TODO: Replace this simulated frontend submission with the verified production enquiry endpoint.
        form.reset();
        trackPvgEvent(form.dataset.pilotForm === "true" ? "pilot_registration_submit" : "contact_form_submit", { path: window.location.pathname });
        if (submitButton) {
          submitButton.disabled = false;
          submitButton.classList.remove("is-loading");
          submitButton.removeAttribute("aria-busy");
          submitButton.innerHTML = originalSubmitText;
        }
        submitted = false;
      }, 520);
    });
  });

  document.querySelectorAll("[data-accordion]").forEach((accordion) => {
    const triggers = Array.from(accordion.querySelectorAll("[data-accordion-trigger]"));
    const panels = Array.from(accordion.querySelectorAll("[data-accordion-panel]"));
    const setOpen = (activeTrigger) => {
      triggers.forEach((trigger) => {
        const isActive = trigger === activeTrigger;
        const panel = document.getElementById(trigger.getAttribute("aria-controls"));
        trigger.setAttribute("aria-expanded", String(isActive));
        if (panel) panel.hidden = !isActive;
      });
    };
    triggers.forEach((trigger, index) => {
      const panel = document.getElementById(trigger.getAttribute("aria-controls"));
      const isOpen = trigger.getAttribute("aria-expanded") === "true";
      if (panel) panel.hidden = !isOpen;
      trigger.addEventListener("click", () => setOpen(trigger));
      trigger.addEventListener("keydown", (event) => {
        if (!["ArrowDown", "ArrowUp", "Home", "End"].includes(event.key)) return;
        event.preventDefault();
        let nextIndex = index;
        if (event.key === "ArrowDown") nextIndex = (index + 1) % triggers.length;
        if (event.key === "ArrowUp") nextIndex = (index - 1 + triggers.length) % triggers.length;
        if (event.key === "Home") nextIndex = 0;
        if (event.key === "End") nextIndex = triggers.length - 1;
        triggers[nextIndex]?.focus();
      });
    });
    if (!panels.some((panel) => !panel.hidden) && triggers[0]) setOpen(triggers[0]);
  });

  const requestForm = document.querySelector("[data-request-form]");
  if (requestForm) {
    const steps = Array.from(requestForm.querySelectorAll("[data-request-step]"));
    const progressItems = Array.from(document.querySelectorAll("[data-request-progress] li"));
    const formCard = document.querySelector("[data-request-form-card]");
    const successCard = document.querySelector("[data-request-success]");
    const reviewOutput = document.querySelector("[data-review-output]");
    const successRef = document.querySelector("[data-success-reference]");
    const whatsappRetry = document.querySelector("[data-whatsapp-retry]");
    const geoButton = requestForm.querySelector("[data-geo-button]");
    const geoStatus = requestForm.querySelector("[data-geo-status]");
    const requestStatus = requestForm.querySelector("[data-request-status]");
    const fastCards = Array.from(requestForm.querySelectorAll("[data-fast-request]"));
    const choiceError = requestForm.querySelector('[data-error-for="requirement_choice"]');
    const whatsappNumber = "919751083000";
    const storageKey = "pvgChargingRequirementDraft";
    let currentStep = 0;
    let submitted = false;

    const requestFields = Array.from(requestForm.querySelectorAll("input, select, textarea"))
      .filter((field) => field.name !== "website");

    const getVisibleFields = () => Array.from(steps[currentStep]?.querySelectorAll("input, select, textarea") || [])
      .filter((field) => field.name !== "website");

    const writeDraft = () => {
      const data = {};
      requestFields.forEach((field) => {
        data[field.name] = field.type === "checkbox" ? field.checked : field.value;
      });
      sessionStorage.setItem(storageKey, JSON.stringify(data));
    };

    const hydrateDraft = () => {
      const search = new URLSearchParams(window.location.search);
      const preferredType = search.get("type");
      try {
        const saved = JSON.parse(sessionStorage.getItem(storageKey) || "{}");
        requestFields.forEach((field) => {
          const value = saved[field.name];
          if (value === undefined) return;
          if (field.type === "checkbox") field.checked = Boolean(value);
          else field.value = value;
        });
      } catch {
        sessionStorage.removeItem(storageKey);
      }
      if (preferredType) {
        const typeField = requestForm.elements["requirement_type"];
        if (typeField) typeField.value = preferredType;
      }
    };

    const updateGeoUi = () => {
      const gpsLocation = requestForm.elements.gps_location?.value || "";
      const accuracy = requestForm.elements.gps_accuracy?.value || "";
      if (!gpsLocation || !geoStatus) return;
      geoStatus.classList.add("is-success");
      geoStatus.textContent = accuracy
        ? `GPS location captured. Accuracy is about ${accuracy} metres.`
        : "GPS location captured.";
    };

    const updateReview = () => {
      if (!reviewOutput) return;
      const rows = requestFields
        .filter((field) => (field.type !== "hidden" || field.name === "gps_accuracy") && field.name !== "consent")
        .filter((field) => field.required || field.value.trim())
        .map((field) => {
          const label = fieldLabel(field);
          const value = field.value || "Not provided";
          if (field.name === "gps_accuracy" && field.value) {
            return `<div><dt>${label}</dt><dd>${field.value} m</dd></div>`;
          }
          return `<div><dt>${label}</dt><dd>${value}</dd></div>`;
        }).join("");
      reviewOutput.innerHTML = `<dl>${rows}</dl>`;
    };

    const getRequestValue = (name) => {
      const field = requestForm.elements[name];
      if (!field) return "";
      if (field.type === "checkbox") return field.checked ? "Yes" : "";
      return String(field.value || "").trim();
    };

    const setRequestStatus = (message, type = "") => {
      if (!requestStatus) return;
      requestStatus.textContent = message || "";
      requestStatus.dataset.statusType = type;
    };

    const setChoiceError = (message) => {
      if (choiceError) choiceError.textContent = message || "";
      fastCards.forEach((card) => card.classList.toggle("is-invalid", Boolean(message)));
    };

    const setRequestValue = (name, value) => {
      if (!value) return;
      const field = requestForm.elements[name];
      if (!field) return;
      field.value = value;
      setError(field, "");
    };

    const syncFastSelection = () => {
      const selectedRequirement = getRequestValue("requirement_type");
      fastCards.forEach((card) => {
        const selected = card.dataset.requirement === selectedRequirement;
        card.classList.toggle("is-selected", selected);
        card.setAttribute("aria-checked", String(selected));
      });
    };

    const selectFastRequest = (button) => {
      setRequestValue("requirement_type", button.dataset.requirement);
      setRequestValue("customer_type", button.dataset.customer);
      setRequestValue("location_type", button.dataset.locationType);
      setRequestValue("battery_status", button.dataset.batteryStatus);
      setRequestValue("charging_need", button.dataset.chargingNeed);
      setRequestValue("requirement_scope", button.dataset.requirementScope);
      setRequestValue("vehicle_count", requestForm.elements.vehicle_count?.value || "1");
      setChoiceError("");
      setRequestStatus(`${button.dataset.requirement} selected. Continue when ready.`, "success");
      syncFastSelection();
      writeDraft();
    };

    const validateRequestNeed = () => {
      if (getRequestValue("requirement_type")) {
        setChoiceError("");
        return true;
      }
      setChoiceError("Select the closest requirement to continue.");
      setRequestStatus("Select one requirement option first.", "error");
      fastCards[0]?.focus({ preventScroll: true });
      return false;
    };

    const buildWhatsappMessage = (reference) => {
      const lines = [
        "PVG-EV charging requirement",
        `Reference: ${reference}`,
        ""
      ];
      const addSection = (title) => {
        if (lines[lines.length - 1] !== "") lines.push("");
        lines.push(title);
      };
      const addLine = (label, value, always = false) => {
        const cleanValue = String(value || "").trim();
        if (cleanValue || always) lines.push(`- ${label}: ${cleanValue || "Not provided"}`);
      };

      addSection("Need");
      addLine("Requirement type", getRequestValue("requirement_type"), true);
      addLine("Customer type", getRequestValue("customer_type"));
      addLine("Requirement scope", getRequestValue("requirement_scope"));

      addSection("Contact and location");
      addLine("Phone", getRequestValue("phone"), true);
      addLine("Name", getRequestValue("name"));
      addLine("Current area", getRequestValue("city"), true);
      addLine("Location type", getRequestValue("location_type"));
      addLine("Landmark / exact spot", getRequestValue("address"));
      addLine("Captured GPS location", getRequestValue("gps_location"));
      addLine("GPS accuracy", getRequestValue("gps_accuracy") ? `${getRequestValue("gps_accuracy")} metres` : "");

      addSection("Vehicle");
      addLine("Vehicle category", getRequestValue("vehicle_category"), true);
      addLine("Vehicle make / model", getRequestValue("vehicle_model"));
      addLine("Number of vehicles", getRequestValue("vehicle_count") || "1");
      addLine("Connector type", getRequestValue("connector_type"));
      addLine("Battery status", getRequestValue("battery_status"));
      addLine("Current battery level", getRequestValue("current_battery_level") ? `${getRequestValue("current_battery_level")}%` : "");
      addLine("Charging need", getRequestValue("charging_need"));
      addLine("What happened", getRequestValue("charging_details"));

      addSection("Optional planning details");
      addLine("Email", getRequestValue("email"));
      addLine("Company / organisation", getRequestValue("company"));
      addLine("Preferred window", getRequestValue("preferred_window"));
      addLine("Preferred date", getRequestValue("target_date"));
      addLine("Preferred time", getRequestValue("preferred_time"));
      addLine("Pilot interest", getRequestValue("pilot_interest"));
      addLine("Additional notes", getRequestValue("additional_notes"));

      lines.push("");
      lines.push("Please review and respond with feasibility, timing and next steps.");
      return lines.join("\n");
    };

    const openWhatsapp = (url) => {
      const isMobile = /Android|iPhone|iPad|iPod|Mobile/i.test(navigator.userAgent);
      if (isMobile) {
        window.location.href = url;
        return true;
      }
      const popup = window.open(url, "_blank");
      if (popup) popup.opener = null;
      if (!popup) window.location.href = url;
      return Boolean(popup);
    };

    const showStep = (index) => {
      currentStep = Math.max(0, Math.min(index, steps.length - 1));
      steps.forEach((step, stepIndex) => {
        const active = stepIndex === currentStep;
        step.hidden = !active;
        step.setAttribute("aria-hidden", String(!active));
      });
      progressItems.forEach((item, itemIndex) => {
        item.classList.toggle("is-active", itemIndex === currentStep);
        item.classList.toggle("is-complete", itemIndex < currentStep);
      });
      if (currentStep === steps.length - 1) updateReview();
      setRequestStatus("");
      steps[currentStep]?.querySelector("input:not([tabindex='-1']), select:not([tabindex='-1']), textarea, button")?.focus({ preventScroll: true });
    };

    const validateStep = () => {
      const fieldsValid = getVisibleFields().map(validateField).every(Boolean);
      const needValid = currentStep === 0 ? validateRequestNeed() : true;
      const locationValid = currentStep === 1 ? validateRequestLocation() : true;
      const valid = fieldsValid && needValid && locationValid;
      if (!valid) steps[currentStep]?.querySelector(".is-invalid")?.focus();
      return valid;
    };

    const validateRequestLocation = () => {
      const addressField = requestForm.elements.address;
      const gpsField = requestForm.elements.gps_location;
      const hasAddress = Boolean(addressField?.value.trim());
      const hasGps = Boolean(gpsField?.value.trim());
      if (hasAddress || hasGps) {
        if (addressField) setError(addressField, "");
        if (gpsField) setError(gpsField, "");
        return true;
      }
      if (addressField) setError(addressField, "Add GPS location or a nearby landmark.");
      return false;
    };

    hydrateDraft();
    updateGeoUi();
    syncFastSelection();
    showStep(0);

    requestFields.forEach((field) => {
      field.addEventListener("blur", () => validateField(field));
      field.addEventListener("input", () => {
        writeDraft();
        if (field.classList.contains("is-invalid")) validateField(field);
      });
      field.addEventListener("change", () => {
        writeDraft();
        if (field.classList.contains("is-invalid")) validateField(field);
      });
    });

    requestForm.querySelectorAll("[data-fast-request]").forEach((button) => {
      button.addEventListener("click", () => selectFastRequest(button));
    });

    requestForm.querySelectorAll("[data-request-next]").forEach((button) => {
      button.addEventListener("click", () => {
        if (!validateStep()) return;
        writeDraft();
        showStep(currentStep + 1);
      });
    });

    requestForm.querySelectorAll("[data-request-back]").forEach((button) => {
      button.addEventListener("click", () => showStep(currentStep - 1));
    });

    geoButton?.addEventListener("click", () => {
      if (!navigator.geolocation) {
        if (geoStatus) geoStatus.textContent = "Location capture is not supported by this browser.";
        return;
      }
      geoButton.disabled = true;
      geoButton.setAttribute("aria-busy", "true");
      if (geoStatus) geoStatus.textContent = "Requesting GPS permission. Please allow location access in the browser prompt.";
      navigator.geolocation.getCurrentPosition((position) => {
        const latitude = position.coords.latitude.toFixed(6);
        const longitude = position.coords.longitude.toFixed(6);
        const accuracy = position.coords.accuracy ? Math.round(position.coords.accuracy) : "";
        const gpsLocation = `Lat ${latitude}, Long ${longitude}`;
        requestForm.elements.latitude.value = latitude;
        requestForm.elements.longitude.value = longitude;
        requestForm.elements.gps_accuracy.value = accuracy;
        requestForm.elements.gps_location.value = gpsLocation;
        updateGeoUi();
        geoButton.disabled = false;
        geoButton.removeAttribute("aria-busy");
        writeDraft();
      }, () => {
        if (geoStatus) geoStatus.textContent = "GPS location was not added. Please allow location permission or continue with the landmark field.";
        geoButton.disabled = false;
        geoButton.removeAttribute("aria-busy");
      }, { enableHighAccuracy: true, timeout: 12000, maximumAge: 30000 });
    });

    requestForm.addEventListener("submit", (event) => {
      event.preventDefault();
      if (submitted) return;
      const website = requestForm.elements.website?.value;
      if (website) return;
      const needValid = Boolean(getRequestValue("requirement_type"));
      const fieldsValid = requestFields.map(validateField).every(Boolean);
      const locationValid = validateRequestLocation();
      if (!needValid || !fieldsValid || !locationValid) {
        const invalidStep = !needValid ? 0 : locationValid ? steps.findIndex((step) => step.querySelector(".is-invalid")) : 1;
        showStep(invalidStep >= 0 ? invalidStep : currentStep);
        if (!needValid) validateRequestNeed();
        return;
      }
      submitted = true;
      const submitButton = requestForm.querySelector('[type="submit"]');
      const originalSubmitText = submitButton?.textContent || "";
      if (submitButton) {
        submitButton.disabled = true;
        submitButton.setAttribute("aria-busy", "true");
        submitButton.textContent = "Opening WhatsApp...";
      }
      const reference = `PVG-EV-${new Date().toISOString().slice(0, 10).replace(/-/g, "")}-${Math.random().toString(36).slice(2, 6).toUpperCase()}`;
      const whatsappUrl = `https://wa.me/${whatsappNumber}?text=${encodeURIComponent(buildWhatsappMessage(reference))}`;
      if (successRef) successRef.textContent = reference;
      if (whatsappRetry) whatsappRetry.href = whatsappUrl;
      formCard?.setAttribute("hidden", "");
      successCard?.removeAttribute("hidden");
      sessionStorage.removeItem(storageKey);
      trackPvgEvent("request_charging_whatsapp_open", { reference, path: window.location.pathname });
      successCard?.focus({ preventScroll: false });
      openWhatsapp(whatsappUrl);
      if (submitButton) {
        submitButton.disabled = false;
        submitButton.removeAttribute("aria-busy");
        submitButton.textContent = originalSubmitText;
      }
    });
  }

  const initPvgChargingJourney = () => {
    const scene = document.querySelector("[data-charging-journey]");
    if (!scene) return;

    const ev = scene.querySelector("[data-journey-ev]");
    const unit = scene.querySelector("[data-journey-unit]");
    const beam = scene.querySelector("[data-journey-beam]");
    const batteryFill = scene.querySelector("[data-journey-battery-fill]");
    const batteryText = scene.querySelector("[data-journey-battery-text]");
    const primaryLabel = scene.querySelector("[data-journey-primary-label]");
    const primary = scene.querySelector("[data-journey-primary]");
    const secondaryLabel = scene.querySelector("[data-journey-secondary-label]");
    const secondary = scene.querySelector("[data-journey-secondary]");
    const route = scene.querySelector("[data-journey-route]");
    if (!ev || !unit || !beam || !batteryFill || !batteryText) return;

    const duration = 17000;
    let frameId = null;
    let startTime = performance.now();

    const lerp = (start, end, amount) => start + (end - start) * amount;
    const ease = (value) => value < .5
      ? 4 * value * value * value
      : 1 - Math.pow(-2 * value + 2, 3) / 2;

    const setPosition = (element, x, y, angle = 0) => {
      element.style.left = `${x}%`;
      element.style.top = `${y}%`;
      element.style.transform = `translate(-50%, -50%) rotate(${angle}deg)`;
    };

    const setBeam = (active) => {
      beam.classList.toggle("is-active", active);
      if (!active) return;
      const sceneRect = scene.getBoundingClientRect();
      const evRect = ev.getBoundingClientRect();
      const unitRect = unit.getBoundingClientRect();
      const startX = unitRect.left - sceneRect.left + unitRect.width * .01;
      const startY = unitRect.top - sceneRect.top + unitRect.height * .56;
      const endX = evRect.left - sceneRect.left + evRect.width * .9;
      const endY = evRect.top - sceneRect.top + evRect.height * .56;
      const dx = endX - startX;
      const dy = endY - startY;
      const cableHeight = beam.offsetHeight || 62;
      beam.style.left = `${startX}px`;
      beam.style.top = `${startY - cableHeight / 2}px`;
      beam.style.width = `${Math.hypot(dx, dy)}px`;
      beam.style.transform = `rotate(${Math.atan2(dy, dx) * 180 / Math.PI}deg)`;
    };

    const setBattery = (level) => {
      const percent = Math.round(level);
      batteryFill.style.width = `${percent}%`;
      batteryText.textContent = `${percent}%`;
      scene.style.setProperty("--battery-level", `${percent}%`);
      scene.dataset.battery = percent < 25 ? "low" : percent < 55 ? "medium" : "high";
    };

    const setStatus = (stage, topLabel, topText, bottomLabel, bottomText) => {
      scene.dataset.stage = stage;
      if (primaryLabel) primaryLabel.textContent = topLabel;
      if (primary) primary.textContent = topText;
      if (secondaryLabel) secondaryLabel.textContent = bottomLabel;
      if (secondary) secondary.textContent = bottomText;
    };

    const render = (time) => {
      const elapsed = (time - startTime) % duration;
      const progress = elapsed / duration;
      let battery = 86;
      let evX = 13;
      let evY = 62;
      let evAngle = -3;
      let unitX = 86;
      let unitY = 41;
      let unitAngle = -4;
      let beamActive = false;
      let routeActive = false;
      let evOpacity = 1;
      let unitOpacity = 1;

      if (progress < .30) {
        const p = ease(progress / .30);
        evX = lerp(18, 37, p);
        evY = lerp(62, 56, p);
        evAngle = lerp(-3, 5, p);
        battery = lerp(86, 18, p);
        evOpacity = progress < .05 ? progress / .05 : 1;
        setStatus("drive", "Battery", `${Math.round(battery)}%`, "Status", "EV moving");
      } else if (progress < .42) {
        evX = 37;
        evY = 56;
        evAngle = 3;
        battery = 18;
        routeActive = true;
        setStatus("alert", "Battery", "18%", "Request", "Received");
      } else if (progress < .60) {
        const p = ease((progress - .42) / .18);
        evX = 37;
        evY = 56;
        evAngle = 2;
        unitX = lerp(86, 82, p);
        unitY = lerp(41, 56, p);
        unitAngle = lerp(-4, -1, p);
        battery = 18;
        routeActive = true;
        setStatus("dispatch", "Unit", "Dispatched", "Request", "Received");
      } else if (progress < .86) {
        const p = ease((progress - .60) / .26);
        evX = 37;
        evY = 56;
        unitX = 82;
        unitY = 56;
        unitAngle = -1;
        battery = lerp(18, 100, p);
        beamActive = true;
        routeActive = true;
        setStatus("charge", "Charging", "Active", "Battery", `${Math.round(battery)}%`);
      } else {
        const p = ease((progress - .86) / .14);
        evX = lerp(37, 106, p);
        evY = lerp(56, 47, p);
        evAngle = lerp(2, -4, p);
        unitX = lerp(82, 67, p);
        unitY = lerp(56, 43, p);
        unitAngle = lerp(-1, -4, p);
        battery = 100;
        routeActive = true;
        evOpacity = p > .72 ? Math.max(0, 1 - (p - .72) / .28) : 1;
        unitOpacity = p > .72 ? Math.max(.72, 1 - (p - .72) / 1.1) : 1;
        setStatus("complete", "Status", "Charge complete", "Battery", "100%");
      }

      setPosition(ev, evX, evY, evAngle);
      setPosition(unit, unitX, unitY, unitAngle);
      ev.style.opacity = evOpacity.toFixed(3);
      unit.style.opacity = unitOpacity.toFixed(3);
      setBattery(battery);
      setBeam(beamActive);
      route?.classList.toggle("is-active", routeActive);
      frameId = requestAnimationFrame(render);
    };

    const pause = () => {
      if (frameId) cancelAnimationFrame(frameId);
      frameId = null;
    };
    const play = () => {
      if (reduceMotion || frameId) return;
      startTime = performance.now();
      frameId = requestAnimationFrame(render);
    };

    if (reduceMotion) {
      setPosition(ev, 36, 55, 2);
      setPosition(unit, 48, 54, -1);
      setBattery(82);
      setStatus("complete", "Status", "Charge complete", "Battery", "82%");
      scene.dataset.reducedMotion = "true";
      return;
    }

    play();
    document.addEventListener("visibilitychange", () => {
      if (document.hidden) pause();
      else play();
    });

    window.__pvgeViz = { destroy: pause, init: play };
  };

  initPvgChargingJourney();

  const cookieBanner = document.querySelector("[data-cookie-banner]");
  const cookieAccept = document.querySelector("[data-cookie-accept]");
  if (cookieBanner && !localStorage.getItem("pvgCookieConsent")) {
    cookieBanner.hidden = false;
    syncHeader();
  }
  cookieAccept?.addEventListener("click", () => {
    localStorage.setItem("pvgCookieConsent", "accepted");
    if (cookieBanner) cookieBanner.hidden = true;
    syncHeader();
  });
})();
