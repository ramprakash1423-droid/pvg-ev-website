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
            <a class="nav-link mobile-contact-link ${active === "contact" ? "is-active" : ""}" href="${url(root, "contact.html")}">Contact</a>
          </div>
          <div class="nav-actions" aria-label="Primary actions">
            <a class="nav-cta nav-cta-request ${active === "request" ? "is-active" : ""}" href="${url(root, "request-charging.html")}" data-event="nav_request_charging">Submit Requirement</a>
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
    const widget = document.createElement("div");
    widget.className = "quick-enquiry";
    widget.setAttribute("data-quick-enquiry", "");
    widget.innerHTML = `
      <button class="quick-enquiry-button" type="button" aria-expanded="false" data-quick-toggle data-event="quick_enquiry_open">
        <span>Need EV Charging?</span>
      </button>
      <div class="quick-enquiry-panel" data-quick-panel hidden>
        <a href="${url(root, "request-charging.html")}" data-event="quick_request_charging"><strong>Submit charging requirement</strong><span>Tell PVG-EV what, where and when you need charging.</span></a>
        <a href="${url(root, "pilot-programme.html#pilot-form")}" data-event="quick_join_pilot"><strong>Join Chennai pilot</strong><span>Register interest for the pilot programme.</span></a>
        <a href="${url(root, "fleet-solutions.html#fleet-assessment")}" data-event="quick_fleet_assessment"><strong>Fleet assessment</strong><span>Share fleet size, routes and charging windows.</span></a>
        <a href="${url(root, "contact.html#contact-form")}" data-event="quick_contact"><strong>Contact PVG-EV</strong><span>Speak with the team about partnerships or projects.</span></a>
      </div>
      <nav class="mobile-action-bar" aria-label="Mobile quick actions">
        <a href="${url(root, "request-charging.html")}" data-event="mobile_request_charging">Request Charging</a>
        <a href="${url(root, "contact.html")}" data-event="mobile_contact">Contact</a>
        <button type="button" data-quick-toggle-mobile aria-expanded="false">More</button>
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
  };

  syncHeader();
  window.addEventListener("scroll", syncHeader, { passive: true });

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
    } else if (field.type === "tel" && value && !/^[0-9+\-\s()]{7,18}$/.test(value)) {
      error = defaultMessages.telephone;
    } else if (field.name === "message" && value && value.length < 12) {
      error = "Please add a little more detail.";
    }

    setError(field, error);
    return !error;
  };

  forms.forEach((form) => {
    const fields = Array.from(form.querySelectorAll("input, select, textarea"));
    const status = form.querySelector("[data-form-status]");

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
      const isValid = fields.map(validateField).every(Boolean);

      if (!isValid) {
        if (status) status.textContent = "Please fix the highlighted fields and submit again.";
        form.querySelector(".is-invalid")?.focus();
        return;
      }

      if (status) status.textContent = form.dataset.pilotForm === "true"
        ? "Thank you. Your Chennai pilot interest has been recorded for review."
        : "Thank you. Your PVG-EV enquiry has been received.";
      form.reset();
      fields.forEach((field) => setError(field, ""));
    });
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
      const reference = `PVG-EV-${new Date().toISOString().slice(0, 10).replace(/-/g, "")}-${Math.random().toString(36).slice(2, 6).toUpperCase()}`;
      if (successRef) successRef.textContent = reference;
      formCard?.setAttribute("hidden", "");
      successCard?.removeAttribute("hidden");
      sessionStorage.removeItem(storageKey);
      trackPvgEvent("request_charging_submit", { reference, path: window.location.pathname });
      successCard?.focus({ preventScroll: false });
    });
  }

  const initPvgOrbitAnimation = () => {
    const container = document.getElementById("orbitContainer");
    if (!container) return;

    const vehicles = [
      document.getElementById("ev1"),
      document.getElementById("ev2"),
      document.getElementById("ev3")
    ].filter(Boolean);
    const battFills = [
      document.getElementById("batt1"),
      document.getElementById("batt2"),
      document.getElementById("batt3")
    ].filter(Boolean);
    const beam = document.getElementById("chargeBeam");
    if (vehicles.length !== battFills.length || !vehicles.length) return;

    const angles = vehicles.map((vehicle, index) => Number(vehicle.dataset.angle || index * 120));
    const batteries = [0.34, 0.72, 0.46].slice(0, vehicles.length);
    const isCharging = vehicles.map(() => false);
    let frameId = null;
    let lastTime = performance.now();

    const radius = () => Math.min(container.offsetWidth, container.offsetHeight) * 0.37;

    const setBeam = (vehicle) => {
      if (!beam || !vehicle) {
        beam?.classList.remove("is-active");
        return;
      }
      const containerRect = container.getBoundingClientRect();
      const vehicleRect = vehicle.getBoundingClientRect();
      const startX = container.offsetWidth / 2;
      const startY = container.offsetHeight / 2;
      const endX = vehicleRect.left - containerRect.left + vehicleRect.width / 2;
      const endY = vehicleRect.top - containerRect.top + vehicleRect.height / 2;
      const dx = endX - startX;
      const dy = endY - startY;
      const length = Math.hypot(dx, dy);
      const angle = Math.atan2(dy, dx) * 180 / Math.PI;
      beam.style.width = `${length}px`;
      beam.style.transform = `rotate(${angle}deg)`;
      beam.classList.add("is-active");
    };

    const updatePositions = () => {
      const centerX = container.offsetWidth / 2;
      const centerY = container.offsetHeight / 2;
      const orbitRadius = radius();
      vehicles.forEach((vehicle, index) => {
        const angleRad = angles[index] * Math.PI / 180;
        const x = centerX + orbitRadius * Math.cos(angleRad) - vehicle.offsetWidth / 2;
        const y = centerY + orbitRadius * Math.sin(angleRad) - vehicle.offsetHeight / 2;
        vehicle.style.left = `${x}px`;
        vehicle.style.top = `${y}px`;
        vehicle.style.transform = `rotate(${angles[index] + 90}deg)`;
      });
      const chargingVehicle = vehicles.find((_, index) => isCharging[index]);
      setBeam(chargingVehicle);
    };

    const updateBatteries = (deltaSeconds) => {
      vehicles.forEach((vehicle, index) => {
        if (isCharging[index]) {
          batteries[index] = Math.min(1, batteries[index] + 0.22 * deltaSeconds);
        } else {
          batteries[index] = Math.max(0, batteries[index] - 0.018 * deltaSeconds);
        }

        if (batteries[index] < 0.18 && !isCharging[index]) {
          isCharging[index] = true;
          vehicle.classList.add("charging");
        }

        if (batteries[index] >= 0.96 && isCharging[index]) {
          isCharging[index] = false;
          vehicle.classList.remove("charging");
        }

        vehicle.classList.toggle("low-battery", batteries[index] < 0.25 && !isCharging[index]);
        battFills[index].style.width = `${Math.round(batteries[index] * 100)}%`;
      });
    };

    const animate = (time) => {
      const deltaSeconds = Math.min((time - lastTime) / 1000, 0.05);
      lastTime = time;
      vehicles.forEach((_, index) => {
        angles[index] = (angles[index] + 22 * deltaSeconds) % 360;
      });
      updateBatteries(deltaSeconds);
      updatePositions();
      if (!reduceMotion) frameId = requestAnimationFrame(animate);
    };

    updateBatteries(0);
    updatePositions();
    if (!reduceMotion) frameId = requestAnimationFrame(animate);

    const handleResize = () => updatePositions();
    window.addEventListener("resize", handleResize, { passive: true });

    window.__pvgeViz = {
      destroy: () => {
        if (frameId) cancelAnimationFrame(frameId);
        frameId = null;
        window.removeEventListener("resize", handleResize);
      },
      init: () => {
        if (!frameId && !reduceMotion) {
          lastTime = performance.now();
          frameId = requestAnimationFrame(animate);
        }
      },
      batteries,
      isCharging,
      angles
    };
  };

  initPvgOrbitAnimation();

  const cookieBanner = document.querySelector("[data-cookie-banner]");
  const cookieAccept = document.querySelector("[data-cookie-accept]");
  if (cookieBanner && !localStorage.getItem("pvgCookieConsent")) {
    cookieBanner.hidden = false;
  }
  cookieAccept?.addEventListener("click", () => {
    localStorage.setItem("pvgCookieConsent", "accepted");
    if (cookieBanner) cookieBanner.hidden = true;
  });
})();
