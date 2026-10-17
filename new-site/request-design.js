'use strict';
// Presentation and accessible validation for the two-step charging enquiry.
// Submission remains in the shared form handler.
window.PVGRequestForm = function(form) {
  form.noValidate = true;
  const fields = [...form.querySelectorAll('input,select,textarea')];
  const alert = form.querySelector('[data-form-alert]');
  const errorFor = name => form.querySelector(`[data-error-for="${name}"]`);
  const groupFor = name => fields.filter(field => field.name === name);
  const clear = field => {
    groupFor(field.name).forEach(item => { item.removeAttribute('aria-invalid'); item.setCustomValidity(''); });
    const error = errorFor(field.name);
    if (error) { error.hidden = true; error.textContent = ''; }
    if (!form.querySelector('[aria-invalid="true"]')) alert.hidden = true;
  };
  form.addEventListener('input', event => { if (fields.includes(event.target)) clear(event.target); });
  form.addEventListener('change', event => { if (fields.includes(event.target)) clear(event.target); });
  return {
    validate(container) {
      let first = null;
      const checked = new Set();
      for (const field of container.querySelectorAll('input,select,textarea')) {
        if (!field.willValidate || checked.has(field.name)) continue;
        checked.add(field.name);
        field.setCustomValidity('');
        if (field.required && ['text','textarea'].includes(field.type) && !field.value.trim()) field.setCustomValidity(field.dataset.errorText);
        if (field.name === 'phone' && !/^[6-9]\d{9}$/.test(PVGForm.normalizePhone(field.value))) field.setCustomValidity('Enter a valid 10-digit Indian mobile number.');
        if (field.checkValidity()) { clear(field); continue; }
        first ||= field;
        groupFor(field.name).forEach(item => item.setAttribute('aria-invalid','true'));
        const error = errorFor(field.name);
        if (error) { error.textContent = field.dataset.errorText || field.validationMessage; error.hidden = false; }
      }
      alert.hidden = !first;
      return first;
    },
    setStep(number) {
      form.dataset.currentStep = number;
      form.querySelector('[data-step-status]').textContent = `Step ${number} of 2`;
      form.querySelectorAll('[data-progress]').forEach(item => item.classList.toggle('is-complete',Number(item.dataset.progress)<number));
      const name = form.elements.name.value.trim();
      const vehicle = form.elements.vehicle_model.value.trim();
      form.querySelector('[data-summary-name]').textContent = name;
      form.querySelector('[data-summary-vehicle]').textContent = vehicle;
      form.querySelector('[data-summary-phone]').textContent = form.elements.phone.value.trim();
      alert.hidden = !form.querySelector(`[data-step="${number}"] [aria-invalid="true"]`);
    },
    complete() {
      form.classList.add('request-complete');
      form.querySelector('[data-step-status]').textContent = 'Complete';
      form.querySelectorAll('[data-progress]').forEach(item => { item.classList.add('is-complete'); item.removeAttribute('aria-current'); });
      form.querySelector('[data-form-fields]').hidden = true;
      alert.hidden = true;
    }
  };
};
