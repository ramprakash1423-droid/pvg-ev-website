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
    { name: "Insights", path: "insights.html", key: "insights" }
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
        return `<a class="nav-link ${active === item.key ? "is-active" : ""}" href="${url(root, item.path)}">${item.name}</a>`;
      }

      return `
        <div class="nav-dropdown ${active === item.key ? "is-active" : ""}" data-dropdown>
          <button class="nav-link dropdown-toggle" type="button" aria-expanded="false" data-dropdown-toggle>
            ${item.name}<span aria-hidden="true">▾</span>
          </button>
          <div class="dropdown-menu" data-dropdown-menu>
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
            <span class="brand-mark" aria-hidden="true"><span class="brand-bolt"></span></span>
            <span class="brand-text"><strong>PVG-EV</strong><small>Prime Ventures Global</small></span>
          </a>
          <button class="nav-toggle" type="button" aria-label="Open menu" aria-expanded="false" aria-controls="site-menu" data-nav-toggle>
            <span></span><span></span><span></span>
          </button>
          <div class="nav-menu nav-menu-client" id="site-menu" data-nav-menu>
            ${navItems.map(navLink).join("")}
            <a class="nav-link mobile-contact-link mobile-request-link ${active === "request" ? "is-active" : ""}" href="${url(root, "request-charging.html")}" data-event="mobile_nav_request_charging">Request Mobile Charging</a>
            <a class="nav-link mobile-contact-link ${active === "contact" ? "is-active" : ""}" href="${url(root, "contact.html")}">Contact</a>
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

    footerMount.innerHTML = `
      <footer class="site-footer">
        <div class="footer-shell footer-shell-client">
          <div class="footer-brand">
            <a class="brand" href="${url(root, "index.html")}" aria-label="PVG-EV home">
              <span class="brand-mark" aria-hidden="true"><span class="brand-bolt"></span></span>
              <span class="brand-text"><strong>PVG-EV</strong><small>Prime Ventures Global</small></span>
            </a>
            <p>PVG-EV is an electric-mobility initiative of Prime Ventures Global. Mobile Charging Station technology is developed by Setrans and introduced in Tamil Nadu through the PVG-EV collaboration.</p>
            <p class="footer-note">Product specifications, charging availability, service coverage and launch dates are subject to testing, certification, operational readiness and local deployment conditions. Images may include development-stage or representative product configurations.</p>
          </div>
          <div class="footer-column">
            <h2>Website</h2>
            ${footerLinks.map(([name, path]) => `<a href="${url(root, path)}">${name}</a>`).join("")}
          </div>
          <div class="footer-column">
            <h2>Solutions</h2>
            <a href="${url(root, "solutions.html#mobile-ev-charging")}">Mobile EV Charging</a>
            <a href="${url(root, "solutions.html#commercial-charging")}">Commercial EV Charging</a>
            <a href="${url(root, "solutions.html#apartment-charging")}">Apartment Charging</a>
            <a href="${url(root, "solutions.html#maintenance-support")}">Maintenance and Support</a>
          </div>
          <div class="footer-column">
            <h2>Contact</h2>
            <a href="${url(root, "request-charging.html")}">Request Charging</a>
            <a href="${url(root, "contact.html")}">Contact PVG-EV</a>
            <a href="${url(root, "pilot-programme.html#pilot-form")}">Join the Chennai Pilot</a>
            <a href="${url(root, "contact.html#contact-form")}">Request a Consultation</a>
            <span class="footer-static">Chennai pilot market: Tamil Nadu, India</span>
          </div>
          <div class="footer-column">
            <h2>Legal</h2>
            ${policyLinks.map(([name, path]) => `<a href="${url(root, path)}">${name}</a>`).join("")}
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

  renderHeader();
  renderFooter();
  renderQuickEnquiry();

  const header = document.querySelector("[data-header]");
  const navToggle = document.querySelector("[data-nav-toggle]");
  const navMenu = document.querySelector("[data-nav-menu]");
  const stickyCta = document.querySelector("[data-quick-enquiry]");
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  const trackPvgEvent = (eventName, detail = {}) => {
    if (!eventName) return;
    window.dataLayer = window.dataLayer || [];
    window.dataLayer.push({ event: eventName, ...detail });
    window.dispatchEvent(new CustomEvent("pvg:analytics", { detail: { event: eventName, ...detail } }));
  };

  const setMenu = (open) => {
    if (!navToggle || !navMenu) return;
    navToggle.setAttribute("aria-expanded", String(open));
    navToggle.setAttribute("aria-label", open ? "Close menu" : "Open menu");
    navMenu.classList.toggle("is-open", open);
    document.body.classList.toggle("menu-open", open);
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
  });

  window.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      setMenu(false);
      closeDropdowns();
      setQuickPanel(false);
    }
  });

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
    header?.classList.toggle("is-scrolled", window.scrollY > 8);
    const hero = document.querySelector(".compact-home-hero, .station-hero-v3, .pilot-hero-v2, .station-product-hero, .request-hero, .page-hero, .hero");
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
    return label?.textContent?.replace("*", "").trim() || field.name;
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
    const originalSubmitText = submitButton?.textContent || "";
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
        submitButton.setAttribute("aria-busy", "true");
        submitButton.textContent = "Submitting...";
      }
      if (status) {
        status.textContent = "Submitting your details...";
        status.classList.remove("is-error", "is-success");
      }

      window.setTimeout(() => {
        if (status) {
          status.textContent = form.dataset.pilotForm === "true"
            ? "Thank you. Your Chennai pilot interest has been recorded for review."
            : "Thank you. Your PVG-EV enquiry has been received.";
          status.classList.remove("is-error");
          status.classList.add("is-success");
        }
        fields.forEach((field) => setError(field, ""));
        form.reset();
        trackPvgEvent(form.dataset.pilotForm === "true" ? "pilot_registration_submit" : "contact_form_submit", { path: window.location.pathname });
        if (submitButton) {
          submitButton.disabled = false;
          submitButton.removeAttribute("aria-busy");
          submitButton.textContent = originalSubmitText;
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
    const geoButton = requestForm.querySelector("[data-geo-button]");
    const geoStatus = requestForm.querySelector("[data-geo-status]");
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

    const updateReview = () => {
      if (!reviewOutput) return;
      const rows = requestFields
        .filter((field) => field.type !== "hidden" && field.name !== "consent")
        .map((field) => {
          const label = fieldLabel(field);
          const value = field.value || "Not provided";
          return `<div><dt>${label}</dt><dd>${value}</dd></div>`;
        }).join("");
      reviewOutput.innerHTML = `<dl>${rows}</dl>`;
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
      steps[currentStep]?.querySelector("input, select, textarea, button")?.focus({ preventScroll: true });
    };

    const validateStep = () => {
      const valid = getVisibleFields().map(validateField).every(Boolean);
      if (!valid) steps[currentStep]?.querySelector(".is-invalid")?.focus();
      return valid;
    };

    hydrateDraft();
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
      if (geoStatus) geoStatus.textContent = "Requesting browser permission for location capture...";
      navigator.geolocation.getCurrentPosition((position) => {
        requestForm.elements.latitude.value = position.coords.latitude.toFixed(6);
        requestForm.elements.longitude.value = position.coords.longitude.toFixed(6);
        if (geoStatus) geoStatus.textContent = "Approximate coordinates added to the draft.";
        writeDraft();
      }, () => {
        if (geoStatus) geoStatus.textContent = "Location was not added. You can continue with the address fields.";
      }, { enableHighAccuracy: false, timeout: 9000, maximumAge: 60000 });
    });

    requestForm.addEventListener("submit", (event) => {
      event.preventDefault();
      if (submitted) return;
      const website = requestForm.elements.website?.value;
      if (website) return;
      const isValid = requestFields.map(validateField).every(Boolean);
      if (!isValid) {
        const invalidStep = steps.findIndex((step) => step.querySelector(".is-invalid"));
        showStep(invalidStep >= 0 ? invalidStep : currentStep);
        return;
      }
      submitted = true;
      const submitButton = requestForm.querySelector('[type="submit"]');
      const originalSubmitText = submitButton?.textContent || "";
      if (submitButton) {
        submitButton.disabled = true;
        submitButton.setAttribute("aria-busy", "true");
        submitButton.textContent = "Submitting...";
      }
      const reference = `PVG-EV-${new Date().toISOString().slice(0, 10).replace(/-/g, "")}-${Math.random().toString(36).slice(2, 6).toUpperCase()}`;
      window.setTimeout(() => {
        if (successRef) successRef.textContent = reference;
        formCard?.setAttribute("hidden", "");
        successCard?.removeAttribute("hidden");
        sessionStorage.removeItem(storageKey);
        trackPvgEvent("request_charging_submit", { reference, path: window.location.pathname });
        successCard?.focus({ preventScroll: false });
        if (submitButton) {
          submitButton.disabled = false;
          submitButton.removeAttribute("aria-busy");
          submitButton.textContent = originalSubmitText;
        }
      }, 520);
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
      beam.style.left = `${startX}px`;
      beam.style.top = `${startY}px`;
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
