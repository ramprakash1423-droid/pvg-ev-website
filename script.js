(function () {
  const headerMount = document.querySelector("[data-site-header]");
  const footerMount = document.querySelector("[data-site-footer]");
  const currentYear = new Date().getFullYear();

  const aboutItems = [
    ["Company", "about/company.html"],
    ["Vision & Mission", "about/vision-mission.html"],
    ["Investors", "about/investors.html"],
    ["Team", "about/team.html"]
  ];

  const productItems = [
    ["Mobile EV Charger", "products/mobile-ev-charger.html"],
    ["Fleet Charging Unit", "products/fleet-charging-unit.html"],
    ["Commercial Charging Station", "products/commercial-charging-station.html"],
    ["Home EV Charger", "products/home-ev-charger.html"],
    ["Energy Management System", "products/energy-management-system.html"]
  ];

  const serviceItems = [
    ["Doorstep EV Charging", "services/doorstep-ev-charging.html"],
    ["Fleet Charging Solutions", "services/fleet-charging-solutions.html"],
    ["Charging Station Installation", "services/charging-station-installation.html"],
    ["AMC & Maintenance", "services/amc-maintenance.html"],
    ["EV Consulting", "services/ev-consulting.html"]
  ];

  const industryItems = [
    ["EV Owners", "industries.html#ev-owners"],
    ["Apartments", "industries.html#apartments"],
    ["Offices & IT Parks", "industries.html#offices"],
    ["Malls & Hotels", "industries.html#destinations"],
    ["Taxi Fleets", "industries.html#fleets"],
    ["Government & Smart Cities", "industries.html#smart-cities"]
  ];

  const normalizeRoot = (root) => {
    if (!root || root === ".") return "";
    return root.replace(/\/?$/, "/");
  };

  const url = (root, path) => `${normalizeRoot(root)}${path}`;

  const dropdown = (label, active, root, items, section) => `
    <div class="dropdown ${active === section ? "is-active" : ""}">
      <div class="dropdown-head">
        <a class="dropdown-link" href="${url(root, `${section}/index.html`)}">${label}</a>
        <button class="dropdown-toggle" type="button" aria-label="Toggle ${label} menu" aria-expanded="false">
          <svg aria-hidden="true" viewBox="0 0 20 20"><path d="m5 8 5 5 5-5" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
        </button>
      </div>
      <div class="dropdown-menu">
        ${items.map(([name, path]) => `<a href="${url(root, path)}">${name}</a>`).join("")}
      </div>
    </div>
  `;

  const renderHeader = () => {
    if (!headerMount) return;
    const root = headerMount.dataset.root || "";
    const active = headerMount.dataset.active || "home";

    headerMount.innerHTML = `
      <header class="site-header" data-header>
        <nav class="nav-shell" aria-label="Primary navigation">
          <a class="brand" href="${url(root, "index.html")}" aria-label="PVG EV home">
            <span class="brand-mark" aria-hidden="true"><span class="brand-bolt"></span></span>
            <span class="brand-text"><strong>PVG EV</strong><small>Prime Ventures Global</small></span>
          </a>
          <button class="nav-toggle" type="button" aria-label="Open menu" aria-expanded="false" aria-controls="site-menu" data-nav-toggle>
            <span></span><span></span><span></span>
          </button>
          <div class="nav-menu" id="site-menu" data-nav-menu>
            <a class="nav-link ${active === "home" ? "is-active" : ""}" href="${url(root, "index.html")}">Home</a>
            ${dropdown("About Us", active, root, aboutItems, "about")}
            ${dropdown("Products", active, root, productItems, "products")}
            ${dropdown("Services", active, root, serviceItems, "services")}
            <a class="nav-link ${active === "technology" ? "is-active" : ""}" href="${url(root, "technology.html")}">Technology</a>
            <a class="nav-link ${active === "industries" ? "is-active" : ""}" href="${url(root, "industries.html")}">Industries</a>
            <a class="nav-link ${active === "sustainability" ? "is-active" : ""}" href="${url(root, "sustainability.html")}">Sustainability</a>
            <a class="nav-link mobile-contact-link ${active === "contact" ? "is-active" : ""}" href="${url(root, "contact.html")}">Contact Us</a>
          </div>
          <a class="nav-cta" href="${url(root, "contact.html")}">Contact Us</a>
        </nav>
      </header>
    `;
  };

  const renderFooter = () => {
    if (!footerMount) return;
    const root = footerMount.dataset.root || "";

    footerMount.innerHTML = `
      <footer class="site-footer">
        <div class="footer-shell">
          <div class="footer-brand">
            <a class="brand" href="${url(root, "index.html")}" aria-label="PVG EV home">
              <span class="brand-mark" aria-hidden="true"><span class="brand-bolt"></span></span>
              <span class="brand-text"><strong>PVG EV</strong><small>Prime Ventures Global</small></span>
            </a>
            <p>EV charging infrastructure, mobile EV charging, fleet charging and smart energy management from Prime Ventures Global.</p>
            <div class="footer-social" aria-label="PVG EV social links">
              <a href="${url(root, "contact.html")}">LinkedIn</a>
              <a href="${url(root, "contact.html")}">X</a>
              <a href="${url(root, "contact.html")}">YouTube</a>
            </div>
          </div>
          <div class="footer-column">
            <h2>About Us</h2>
            ${aboutItems.map(([name, path]) => `<a href="${url(root, path)}">${name}</a>`).join("")}
          </div>
          <div class="footer-column">
            <h2>Products</h2>
            ${productItems.map(([name, path]) => `<a href="${url(root, path)}">${name}</a>`).join("")}
          </div>
          <div class="footer-column">
            <h2>Services</h2>
            ${serviceItems.map(([name, path]) => `<a href="${url(root, path)}">${name}</a>`).join("")}
          </div>
          <div class="footer-column">
            <h2>Industries</h2>
            ${industryItems.map(([name, path]) => `<a href="${url(root, path)}">${name}</a>`).join("")}
          </div>
          <div class="footer-column">
            <h2>Contact</h2>
            <a href="${url(root, "technology.html")}">Technology Platform</a>
            <a href="${url(root, "industries.html")}">Industries</a>
            <a href="${url(root, "sustainability.html")}">Sustainability</a>
            <a href="${url(root, "contact.html")}">Request Consultation</a>
          </div>
        </div>
        <div class="footer-bottom">
          <span>PVG EV by Prime Ventures Global</span>
          <span>Copyright ${currentYear}. All rights reserved.</span>
        </div>
      </footer>
    `;
  };

  renderHeader();
  renderFooter();

  const header = document.querySelector("[data-header]");
  const navToggle = document.querySelector("[data-nav-toggle]");
  const navMenu = document.querySelector("[data-nav-menu]");
  const dropdownButtons = Array.from(document.querySelectorAll(".dropdown-toggle"));
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

  dropdownButtons.forEach((button) => {
    button.addEventListener("click", () => {
      const parent = button.closest(".dropdown");
      const open = !parent.classList.contains("is-open");
      document.querySelectorAll(".dropdown.is-open").forEach((item) => {
        if (item !== parent) {
          item.classList.remove("is-open");
          item.querySelector(".dropdown-toggle")?.setAttribute("aria-expanded", "false");
        }
      });
      parent.classList.toggle("is-open", open);
      button.setAttribute("aria-expanded", String(open));
    });
  });

  document.addEventListener("click", (event) => {
    if (!event.target.closest(".dropdown")) {
      document.querySelectorAll(".dropdown.is-open").forEach((item) => {
        item.classList.remove("is-open");
        item.querySelector(".dropdown-toggle")?.setAttribute("aria-expanded", "false");
      });
    }
  });

  document.querySelectorAll(".nav-menu a").forEach((link) => {
    link.addEventListener("click", () => setMenu(false));
  });

  window.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      setMenu(false);
      document.querySelectorAll(".dropdown.is-open").forEach((item) => item.classList.remove("is-open"));
    }
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

  const form = document.querySelector("[data-contact-form]");
  const status = document.querySelector("[data-form-status]");

  const messages = {
    name: "Please enter your name.",
    email: "Please enter a valid email address.",
    phone: "Please enter a valid phone number.",
    requirement: "Please choose a requirement type.",
    message: "Please share a short message."
  };

  const setError = (field, message) => {
    const error = document.querySelector(`[data-error-for="${field.name}"]`);
    field.classList.toggle("is-invalid", Boolean(message));
    field.setAttribute("aria-invalid", message ? "true" : "false");
    if (error) error.textContent = message || "";
  };

  const validateField = (field) => {
    const value = field.value.trim();
    let error = "";

    if (field.required && !value) {
      error = messages[field.name] || "This field is required.";
    } else if (field.type === "email" && value && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) {
      error = messages.email;
    } else if (field.type === "tel" && value && !/^[0-9+\-\s()]{7,18}$/.test(value)) {
      error = messages.phone;
    } else if (field.name === "message" && value && value.length < 12) {
      error = "Please add a little more detail.";
    }

    setError(field, error);
    return !error;
  };

  if (form) {
    const fields = Array.from(form.querySelectorAll("input, select, textarea"));

    fields.forEach((field) => {
      field.addEventListener("blur", () => validateField(field));
      field.addEventListener("input", () => {
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

      if (status) status.textContent = "Thank you. Your PVG EV enquiry has been received.";
      form.reset();
      fields.forEach((field) => setError(field, ""));
    });
  }
})();
