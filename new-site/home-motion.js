'use strict';

(() => {
  const motion = matchMedia('(prefers-reduced-motion: reduce)');
  const hero = document.querySelector('.visual-hero');
  const scenes = [...document.querySelectorAll('[data-hero-scene]')];
  const choices = [...document.querySelectorAll('[data-hero-choice]')];
  const playback = document.querySelector('[data-hero-playback]');
  const controls = document.querySelector('.hero-gallery-controls');
  let current = 0, elapsed = 0, previousTime = 0, frame = 0;
  let userPaused = false, inView = true, interacting = false;
  const interval = 7500;
  const running = () => !userPaused && inView && !interacting && !document.hidden && !motion.matches;

  function updatePlayback() {
    const paused = userPaused || motion.matches;
    playback.setAttribute('aria-label', motion.matches ? 'Show next image' : paused ? 'Play image animation' : 'Pause image animation');
    playback.querySelector('path').setAttribute('d', paused ? 'M8 5v14l11-7z' : 'M7 5h3v14H7zM14 5h3v14h-3z');
    hero.classList.toggle('hero-paused', !running());
  }
  function selectScene(index) {
    current = (index + scenes.length) % scenes.length;
    elapsed = 0;
    scenes.forEach((scene, i) => {
      scene.classList.toggle('is-active', i === current);
      scene.setAttribute('aria-hidden', String(i !== current));
    });
    choices.forEach((choice, i) => {
      choice.setAttribute('aria-pressed', String(i === current));
      choice.style.setProperty('--scene-progress', '0');
    });
  }
  function tick(time) {
    frame = 0;
    if (!running()) { previousTime = 0; return; }
    if (previousTime) elapsed += Math.min(time - previousTime, 100);
    previousTime = time;
    if (elapsed >= interval) selectScene(current + 1);
    choices[current].style.setProperty('--scene-progress', String(elapsed / interval));
    frame = requestAnimationFrame(tick);
  }
  function sync() {
    updatePlayback();
    if (frame) cancelAnimationFrame(frame);
    frame = 0; previousTime = 0;
    if (running()) frame = requestAnimationFrame(tick);
  }
  if (hero && scenes.length === 3 && choices.length === 3 && playback && controls) {
    scenes.forEach(scene => { scene.hidden = false; });
    controls.hidden = false;
    hero.classList.add('hero-gallery-ready');
    choices.forEach((choice, i) => choice.addEventListener('click', () => {
      userPaused = true; selectScene(i); sync();
    }));
    playback.addEventListener('click', () => {
      // Reduced-motion visitors can still advance the scenes manually.
      if (motion.matches) { selectScene(current + 1); return; }
      userPaused = !userPaused; interacting = false; sync();
    });
    controls.addEventListener('focusin', () => { interacting = true; sync(); });
    controls.addEventListener('focusout', event => {
      if (!controls.contains(event.relatedTarget)) { interacting = false; sync(); }
    });
    document.addEventListener('visibilitychange', sync);
    motion.addEventListener('change', sync);
    if ('IntersectionObserver' in window) {
      new IntersectionObserver(entries => { inView = entries[0].isIntersecting; sync(); }, { threshold: .1 }).observe(hero);
    }
    sync();
  }

  const gallery = document.getElementById('home-solutions-gallery');
  const galleryNav = document.querySelector('.home-gallery-navigation');
  if (gallery && galleryNav) {
    const cards = [...gallery.querySelectorAll('.visual-card')];
    const previous = galleryNav.querySelector('[data-gallery-prev]');
    const next = galleryNav.querySelector('[data-gallery-next]');
    const counter = galleryNav.querySelector('[data-gallery-count]');
    let position = 0, scheduled = false;
    document.body.classList.add('home-gallery-ready');
    galleryNav.hidden = false;
    gallery.setAttribute('aria-roledescription', 'carousel');
    function updateGallery() {
      scheduled = false;
      const left = gallery.getBoundingClientRect().left;
      let distance = Infinity;
      cards.forEach((card, index) => {
        const d = Math.abs(card.getBoundingClientRect().left - left);
        if (d < distance) { distance = d; position = index; }
      });
      previous.disabled = position === 0;
      next.disabled = position === cards.length - 1;
      counter.textContent = `${String(position + 1).padStart(2, '0')} / ${String(cards.length).padStart(2, '0')}`;
    }
    function go(index, focus = false) {
      const card = cards[Math.max(0, Math.min(cards.length - 1, index))];
      const left = gallery.scrollLeft + card.getBoundingClientRect().left - gallery.getBoundingClientRect().left;
      if (focus) card.focus({ preventScroll: true });
      gallery.scrollTo({ left, behavior: motion.matches ? 'auto' : 'smooth' });
    }
    previous.addEventListener('click', () => go(position - 1));
    next.addEventListener('click', () => go(position + 1));
    gallery.addEventListener('keydown', event => {
      if (!['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) return;
      event.preventDefault();
      go(event.key === 'Home' ? 0 : event.key === 'End' ? cards.length - 1 : position + (event.key === 'ArrowRight' ? 1 : -1), true);
    });
    gallery.addEventListener('scroll', () => { if (!scheduled) { scheduled = true; requestAnimationFrame(updateGallery); } }, { passive: true });
    addEventListener('resize', updateGallery);
    updateGallery();
  }

  const entrances = [...document.querySelectorAll('.visual-hero-copy > *, .visual-heading, .visual-partners, .visual-pilot > div, .visual-place-copy > *')];
  let revealObserver;
  function configureReveals() {
    revealObserver?.disconnect();
    entrances.forEach(item => item.classList.remove('motion-pending'));
    if (motion.matches || !('IntersectionObserver' in window)) return;
    revealObserver = new IntersectionObserver(entries => {
      entries.forEach(entry => {
        if (!entry.isIntersecting) return;
        entry.target.classList.remove('motion-pending');
        revealObserver.unobserve(entry.target);
      });
    }, { threshold: .08 });
    entrances.forEach((item, i) => {
      item.style.setProperty('--entrance-delay', `${(i % 3) * 85}ms`);
      item.classList.add('motion-item', 'motion-pending');
      item.addEventListener('focusin', () => item.classList.remove('motion-pending'), { once: true });
      revealObserver.observe(item);
    });
  }
  configureReveals();
  motion.addEventListener('change', configureReveals);

  const place = document.querySelector('.visual-place');
  let scrollFrame = 0;
  function updateDepth() {
    scrollFrame = 0;
    if (!place) return;
    const bounds = place.getBoundingClientRect();
    if (motion.matches) { place.style.setProperty('--place-shift', '0px'); return; }
    if (bounds.bottom < 0 || bounds.top > innerHeight) return;
    const amount = Math.max(-1, Math.min(1, (innerHeight / 2 - bounds.top - bounds.height / 2) / innerHeight));
    place.style.setProperty('--place-shift', `${amount * 32}px`);
  }
  addEventListener('scroll', () => { if (!scrollFrame) scrollFrame = requestAnimationFrame(updateDepth); }, { passive: true });
  motion.addEventListener('change', updateDepth);
  updateDepth();
})();
