'use strict';

// Without JavaScript, these remain ordinary links to three complete sections.
(() => {
  const choices = document.querySelector('[data-charging-options]');
  if (!choices) return;
  const tabs = [...choices.querySelectorAll('a')];
  const panels = tabs.map(tab => document.getElementById(tab.hash.slice(1)));
  if (!tabs.length || panels.some(panel => !panel)) return;

  function select(index, focus = false) {
    tabs.forEach((tab, position) => {
      const active = position === index;
      tab.setAttribute('aria-selected', String(active));
      tab.tabIndex = active ? 0 : -1;
      panels[position].hidden = !active;
    });
    if (focus) tabs[index].focus();
  }

  choices.setAttribute('role', 'tablist');
  tabs.forEach((tab, index) => {
    tab.setAttribute('role', 'tab');
    tab.setAttribute('aria-controls', panels[index].id);
    panels[index].setAttribute('role', 'tabpanel');
    panels[index].setAttribute('aria-labelledby', tab.id);
    panels[index].tabIndex = 0;
    tab.addEventListener('click', event => {
      event.preventDefault();
      select(index);
    });
    tab.addEventListener('keydown', event => {
      const next = { ArrowRight: (index + 1) % tabs.length, ArrowLeft: (index - 1 + tabs.length) % tabs.length, Home: 0, End: tabs.length - 1 };
      if (Object.hasOwn(next, event.key)) {
        event.preventDefault();
        select(next[event.key], true);
      } else if (event.key === ' ') {
        event.preventDefault();
        select(index);
      }
    });
  });
  const initial = tabs.findIndex(tab => tab.hash === location.hash);
  select(initial < 0 ? 0 : initial);
  addEventListener('hashchange', () => {
    const linked = tabs.findIndex(tab => tab.hash === location.hash);
    if (linked >= 0) select(linked);
  });
})();
