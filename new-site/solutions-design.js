'use strict';
// Keep the native section links usable without JavaScript; highlight the section in view.
const solutionLinks = [...document.querySelectorAll('.sol-picker a')];
const solutionSections = solutionLinks.map(link => document.getElementById(link.hash.slice(1))).filter(Boolean);
let solutionScrollScheduled = false;
function updateSolutionNavigation() {
  solutionScrollScheduled = false;
  const picker = document.querySelector('.sol-picker');
  if (!picker) return;
  const readingLine = picker.getBoundingClientRect().bottom + 80;
  const section = solutionSections.find(item => {
    const bounds = item.getBoundingClientRect();
    return bounds.top <= readingLine && bounds.bottom > readingLine;
  });
  for (const link of solutionLinks) {
    if (section && link.hash === '#' + section.id) link.setAttribute('aria-current', 'location');
    else link.removeAttribute('aria-current');
  }
}
function scheduleSolutionNavigation() {
  if (!solutionScrollScheduled) {
    solutionScrollScheduled = true;
    requestAnimationFrame(updateSolutionNavigation);
  }
}
addEventListener('scroll', scheduleSolutionNavigation, { passive: true });
addEventListener('resize', scheduleSolutionNavigation);
updateSolutionNavigation();
