(function () {
  'use strict';

  const params = new URLSearchParams(window.location.search);
  const key = params.get('key');
  let version = window.__UI_COMPARE_VERSION || '';

  function keyedPath(path) {
    return path + '?key=' + encodeURIComponent(key || '');
  }

  function setStatus(text, state) {
    const status = document.querySelector('[data-connection-status]');
    if (!status) return;
    status.textContent = text;
    status.dataset.state = state;
  }

  async function poll() {
    if (!key) return;
    try {
      const response = await fetch(keyedPath('/meta'), { cache: 'no-store' });
      if (!response.ok) throw new Error('meta request failed');
      const data = await response.json();
      setStatus('Live', 'live');
      if (data.version && version && data.version !== version) {
        window.location.reload();
        return;
      }
      version = data.version || version;
    } catch (error) {
      setStatus('Reconnecting', 'waiting');
    }
  }

  async function sendEvent(event) {
    if (!key) return;
    try {
      await fetch(keyedPath('/events'), {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ ...event, timestamp: Date.now() })
      });
    } catch (error) {
      setStatus('Feedback not saved', 'error');
    }
  }

  document.addEventListener('click', function (event) {
    const target = event.target.closest('[data-choice]');
    if (!target) return;
    sendEvent({
      type: 'click',
      choice: target.dataset.choice,
      text: target.textContent.trim().slice(0, 2000),
      id: target.id || null
    });
  });

  document.querySelectorAll('[data-choice]').forEach(function (element) {
    if (!element.hasAttribute('tabindex')) element.tabIndex = 0;
    if (!element.hasAttribute('role')) element.setAttribute('role', 'button');
  });

  document.addEventListener('keydown', function (event) {
    const target = event.target.closest('[data-choice]');
    if (!target || (event.key !== 'Enter' && event.key !== ' ')) return;
    event.preventDefault();
    target.click();
  });

  window.toggleSelect = function (element) {
    const container = element.closest('.compare-grid, .options, .cards');
    const multi = container && container.hasAttribute('data-multiselect');
    if (container && !multi) {
      container.querySelectorAll('[data-choice]').forEach(function (item) {
        item.classList.remove('selected');
      });
    }
    if (multi) {
      element.classList.toggle('selected');
    } else {
      element.classList.add('selected');
    }
  };

  setStatus('Live', 'live');
  window.setInterval(poll, 1000);
})();
