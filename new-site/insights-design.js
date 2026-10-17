'use strict';
// Topic buttons enhance the existing search and select filter; the select remains a no-JS fallback.
(() => {
  const category = document.getElementById('insight-category');
  const search = document.getElementById('insight-search');
  const topics = document.querySelector('.journal-topics');
  if (!category || !search || !topics) return;
  const sync = () => topics.querySelectorAll('button').forEach(button => {
    button.setAttribute('aria-pressed', String(button.dataset.journalTopic === category.value));
  });
  topics.hidden = false;
  category.closest('.field').hidden = true;
  search.form.classList.add('journal-enhanced');
  topics.addEventListener('click', event => {
    const button = event.target.closest('[data-journal-topic]');
    if (!button) return;
    category.value = button.dataset.journalTopic;
    category.dispatchEvent(new Event('change', { bubbles: true }));
  });
  category.addEventListener('change', sync);
  document.querySelector('[data-journal-reset]').addEventListener('click', () => {
    search.value = '';
    category.value = 'all';
    category.dispatchEvent(new Event('change', { bubbles: true }));
    search.focus();
  });
  sync();
})();
