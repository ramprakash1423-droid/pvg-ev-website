(function () {
  const headerMount = document.querySelector("[data-site-header]");
  const footerMount = document.querySelector("[data-site-footer]");
  const currentYear = new Date().getFullYear();

  const navItems = [
    ["Home", "index.html", "home"],
    ["Mobile Charging Station", "mobile-charging-station.html", "station"],
    ["Solutions", "solutions.html", "solutions"],
    ["Fleet Solutions", "fleet-solutions.html", "fleet"],
    ["About PVG-EV", "about-pvg-ev.html", "about"],
    ["PVG-EV × Setrans", "collaboration.html", "collaboration"],
    ["Pilot Programme", "pilot-programme.html", "pilot"],
    ["Insights", "insights.html", "insights"]
  ];

  const footerLinks = [
    ["Mobile Charging Station", "mobile-charging-station.html"],
    ["Solutions", "solutions.html"],
    ["Fleet Solutions", "fleet-solutions.html"],
    ["PVG-EV × Setrans", "collaboration.html"],
    ["Pilot Programme", "pilot-programme.html"],
    ["Insights", "insights.html"]
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
            ${navItems.map(([name, path, key]) => `<a class="nav-link ${active === key ? "is-active" : ""}" href="${url(root, path)}">${name}</a>`).join("")}
            <a class="nav-link mobile-contact-link ${active === "contact" ? "is-active" : ""}" href="${url(root, "contact.html")}">Contact</a>
          </div>
          <a class="nav-cta ${active === "contact" ? "is-active" : ""}" href="${url(root, "contact.html")}">Contact</a>
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
            <p>PVG-EV is an electric-mobility initiative of Prime Ventures Global. Mobile Charging Station technology is developed and manufactured by Setrans and introduced in Tamil Nadu through the PVG-EV collaboration.</p>
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

  renderHeader();
  renderFooter();

  const header = document.querySelector("[data-header]");
  const navToggle = document.querySelector("[data-nav-toggle]");
  const navMenu = document.querySelector("[data-nav-menu]");
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

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

  window.addEventListener("keydown", (event) => {
    if (event.key === "Escape") setMenu(false);
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
