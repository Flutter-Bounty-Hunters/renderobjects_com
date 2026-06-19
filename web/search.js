// Wires the navbar's "Search docs..." button up to a Pagefind-powered search
// modal. Pagefind itself (the index + UI bundle) is generated at build time
// by `npx pagefind --site build/jaspr` and lives under /pagefind/ — see
// .github/workflows/deploy.yml. The UI library is only fetched the first
// time a visitor opens search, so pages that never use search pay no cost.

(function () {
  var modal = null;
  var pagefindUI = null;
  var loadingPromise = null;

  function buildModal() {
    var overlay = document.createElement('div');
    overlay.id = 'search-modal-overlay';
    overlay.className = 'search-modal-overlay';
    overlay.innerHTML =
      '<div class="search-modal" role="dialog" aria-modal="true" aria-label="Search">' +
      '<div id="pagefind-search"></div>' +
      '</div>';
    overlay.addEventListener('click', function (e) {
      if (e.target === overlay) closeModal();
    });
    document.body.appendChild(overlay);
    return overlay;
  }

  function loadPagefindUI() {
    if (loadingPromise) return loadingPromise;
    loadingPromise = new Promise(function (resolve, reject) {
      var cssLink = document.createElement('link');
      cssLink.rel = 'stylesheet';
      cssLink.href = '/pagefind/pagefind-ui.css';
      document.head.appendChild(cssLink);

      var scriptTag = document.createElement('script');
      scriptTag.src = '/pagefind/pagefind-ui.js';
      scriptTag.onload = resolve;
      scriptTag.onerror = reject;
      document.head.appendChild(scriptTag);
    });
    return loadingPromise;
  }

  function openModal() {
    if (!modal) modal = buildModal();
    modal.classList.add('search-modal-open');
    document.body.classList.add('search-modal-active');

    loadPagefindUI()
      .then(function () {
        if (!pagefindUI) {
          pagefindUI = new window.PagefindUI({
            element: '#pagefind-search',
            showSubResults: true,
            showImages: false,
          });
        }
        var input = modal.querySelector('.pagefind-ui__search-input');
        if (input) input.focus();
      })
      .catch(function () {
        var container = modal.querySelector('#pagefind-search');
        if (container) {
          container.textContent =
            "Search isn't available right now. Try again after the next deploy.";
        }
      });
  }

  function closeModal() {
    if (modal) modal.classList.remove('search-modal-open');
    document.body.classList.remove('search-modal-active');
  }

  document.addEventListener('DOMContentLoaded', function () {
    var trigger = document.getElementById('site-search-trigger');
    if (trigger) trigger.addEventListener('click', openModal);

    document.addEventListener('keydown', function (e) {
      var isShortcut = (e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k';
      if (isShortcut) {
        e.preventDefault();
        if (modal && modal.classList.contains('search-modal-open')) {
          closeModal();
        } else {
          openModal();
        }
      } else if (e.key === 'Escape' && modal && modal.classList.contains('search-modal-open')) {
        closeModal();
      }
    });
  });
})();
