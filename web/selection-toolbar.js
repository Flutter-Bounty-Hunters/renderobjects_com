// Shows a small floating toolbar (Copy / Share / Report Mistake) whenever the
// reader selects text that lies entirely within a page's `.content` area
// (the markdown body of a Guide, API doc, or Example). "Report Mistake"
// opens a new GitHub issue prefilled with the page and the selected text.

(function () {
  var REPO_URL = 'https://github.com/Flutter-Bounty-Hunters/renderobjects_com';

  var BLOCK_SELECTOR = 'p, li, h2, h3, h4, h5, h6, pre, blockquote, td, th';

  var toolbar = null;
  var hideTimer = null;
  var lastText = '';
  var lastRange = null;

  var ICONS = {
    copy:
      '<svg width="14" height="14" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
      '<rect x="5.5" y="5.5" width="8" height="8" rx="1.5"></rect>' +
      '<path d="M3.5 10.5 a1.5 1.5 0 0 1 -1.5 -1.5 v-5 a1.5 1.5 0 0 1 1.5 -1.5 h5 a1.5 1.5 0 0 1 1.5 1.5"></path>' +
      '</svg>',
    share:
      '<svg width="13" height="13" viewBox="0 0 16 16" fill="currentColor" aria-hidden="true">' +
      '<path d="M9.46 6.93 14.7 1h-1.24l-4.55 5.15L5.3 1H1.06l5.5 7.83L1.06 15h1.24l4.8-5.43L11.06 15h4.24L9.46 6.93Zm-1.7 1.92-.56-.79L2.8 1.9h1.9l3.58 5.08.56.79 4.63 6.58h-1.9L7.76 8.85Z"></path>' +
      '</svg>',
    report:
      '<svg width="14" height="14" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
      '<path d="M8 1.5 L14.5 13 a1 1 0 0 1 -0.9 1.5 H2.4 a1 1 0 0 1 -0.9 -1.5 Z"></path>' +
      '<path d="M8 6 V9"></path>' +
      '<path d="M8 11.5 H8.01"></path>' +
      '</svg>',
  };

  function elementOf(node) {
    return node.nodeType === Node.TEXT_NODE ? node.parentElement : node;
  }

  function closestContent(node) {
    var el = elementOf(node);
    return el ? el.closest('.content') : null;
  }

  function closestBlock(node) {
    var el = elementOf(node);
    return el ? el.closest(BLOCK_SELECTOR) : null;
  }

  // Returns the selected text within `block`, with the portion that the
  // reader actually selected wrapped in markdown bold — so a report can
  // include full paragraph context plus a precise pointer to the mistake.
  function markBlockSelection(block, selRange) {
    var blockRange = document.createRange();
    blockRange.selectNodeContents(block);

    var startContainer = selRange.startContainer;
    var startOffset = selRange.startOffset;
    if (selRange.compareBoundaryPoints(Range.START_TO_START, blockRange) <= 0) {
      startContainer = blockRange.startContainer;
      startOffset = blockRange.startOffset;
    }

    var endContainer = selRange.endContainer;
    var endOffset = selRange.endOffset;
    if (selRange.compareBoundaryPoints(Range.END_TO_END, blockRange) >= 0) {
      endContainer = blockRange.endContainer;
      endOffset = blockRange.endOffset;
    }

    var preRange = document.createRange();
    preRange.setStart(blockRange.startContainer, blockRange.startOffset);
    preRange.setEnd(startContainer, startOffset);

    var midRange = document.createRange();
    midRange.setStart(startContainer, startOffset);
    midRange.setEnd(endContainer, endOffset);

    var postRange = document.createRange();
    postRange.setStart(endContainer, endOffset);
    postRange.setEnd(blockRange.endContainer, blockRange.endOffset);

    // The server renders pretty-printed HTML, so text nodes carry raw
    // indentation/newlines that aren't part of the actual prose — collapse
    // that whitespace the same way the browser would when displaying it.
    var pre = preRange.toString().replace(/\s+/g, ' ');
    var mid = midRange.toString().replace(/\s+/g, ' ').trim();
    var post = postRange.toString().replace(/\s+/g, ' ');

    if (!mid) return (pre + post).replace(/\s+/g, ' ').trim();
    return (pre + '**' + mid + '**' + post).replace(/\s+/g, ' ').trim();
  }

  // Builds the full paragraph(s) the selection touches, with the selected
  // portion bolded, so a GitHub issue retains complete sentence context
  // instead of just the (possibly mid-sentence) selected fragment.
  function buildSelectionContext(selRange) {
    var contentEl = closestContent(selRange.startContainer);
    var startBlock = closestBlock(selRange.startContainer);
    var endBlock = closestBlock(selRange.endContainer);
    if (!contentEl || !startBlock || !endBlock) return null;

    var blocks = Array.from(contentEl.querySelectorAll(BLOCK_SELECTOR));
    var startIdx = blocks.indexOf(startBlock);
    var endIdx = blocks.indexOf(endBlock);
    if (startIdx === -1 || endIdx === -1) return null;

    var paragraphs = [];
    for (var i = startIdx; i <= endIdx; i++) {
      paragraphs.push(markBlockSelection(blocks[i], selRange));
    }
    return paragraphs.join('\n\n');
  }

  function toBlockquote(text) {
    return text
      .split('\n')
      .map(function (line) {
        return line ? '> ' + line : '>';
      })
      .join('\n');
  }

  function selectionWithinContent(selection) {
    if (!selection || selection.isCollapsed || selection.rangeCount === 0) return false;
    var anchorContent = closestContent(selection.anchorNode);
    var focusContent = closestContent(selection.focusNode);
    return !!anchorContent && anchorContent === focusContent;
  }

  function buildToolbar() {
    var el = document.createElement('div');
    el.className = 'selection-toolbar';
    el.innerHTML =
      '<button type="button" class="selection-toolbar-btn" data-action="copy">' + ICONS.copy + '<span>Copy</span></button>' +
      '<div class="selection-toolbar-sep"></div>' +
      '<button type="button" class="selection-toolbar-btn" data-action="share">' + ICONS.share + '<span>Share to X</span></button>' +
      '<div class="selection-toolbar-sep"></div>' +
      '<button type="button" class="selection-toolbar-btn" data-action="report">' + ICONS.report + '<span>Report Mistake</span></button>';

    // Prevent mousedown on the toolbar from collapsing the active selection.
    el.addEventListener('mousedown', function (e) {
      e.preventDefault();
    });
    el.addEventListener('click', onToolbarClick);
    document.body.appendChild(el);
    return el;
  }

  function flashLabel(button, text) {
    var span = button.querySelector('span');
    var original = span.textContent;
    span.textContent = text;
    setTimeout(function () {
      span.textContent = original;
    }, 1200);
  }

  function onToolbarClick(e) {
    var button = e.target.closest('.selection-toolbar-btn');
    if (!button) return;
    var action = button.getAttribute('data-action');
    if (action === 'copy') doCopy(button);
    else if (action === 'share') doShare();
    else if (action === 'report') doReport();
  }

  function doCopy(button) {
    navigator.clipboard.writeText(lastText).then(function () {
      flashLabel(button, 'Copied!');
    });
  }

  function truncate(text, maxLength) {
    if (text.length <= maxLength) return text;
    return text.slice(0, maxLength - 1).trimEnd() + '…';
  }

  function doShare() {
    var quote = '"' + truncate(lastText, 220) + '"';
    var tweetUrl =
      'https://twitter.com/intent/tweet?text=' + encodeURIComponent(quote) +
      '&url=' + encodeURIComponent(window.location.href);
    window.open(tweetUrl, 'share-to-x', 'noopener,width=550,height=420');
  }

  function doReport() {
    var context = lastRange ? buildSelectionContext(lastRange) : null;
    var quoted = context ? toBlockquote(context) : toBlockquote(lastText);
    var selectedNote = context
      ? '**Selected text is bolded below, with the surrounding paragraph(s) for context:**\n'
      : '**Selected text:**\n';

    var title = 'Possible mistake on "' + document.title + '"';
    var body =
      '**Page:** ' + window.location.href + '\n\n' +
      selectedNote + quoted + '\n\n' +
      "**What's wrong:**\n";
    var url =
      REPO_URL + '/issues/new?title=' + encodeURIComponent(title) + '&body=' + encodeURIComponent(body);
    window.open(url, '_blank', 'noopener');
    hideToolbar();
  }

  function positionToolbar(rect) {
    var margin = 8;
    toolbar.style.display = 'flex';
    var toolbarRect = toolbar.getBoundingClientRect();

    var left = rect.left + rect.width / 2 - toolbarRect.width / 2;
    left = Math.max(margin, Math.min(left, window.innerWidth - toolbarRect.width - margin));

    var top = rect.top - toolbarRect.height - margin;
    if (top < margin) top = rect.bottom + margin;

    toolbar.style.left = left + 'px';
    toolbar.style.top = top + 'px';
  }

  function showToolbar(selection) {
    lastText = selection.toString().trim();
    if (!lastText) return;
    lastRange = selection.getRangeAt(0).cloneRange();
    if (!toolbar) toolbar = buildToolbar();

    var rect = lastRange.getBoundingClientRect();
    positionToolbar(rect);
    toolbar.classList.add('selection-toolbar-visible');
  }

  function hideToolbar() {
    if (toolbar) toolbar.classList.remove('selection-toolbar-visible');
  }

  function onSelectionChange() {
    clearTimeout(hideTimer);
    hideTimer = setTimeout(function () {
      var selection = window.getSelection();
      if (selectionWithinContent(selection)) {
        showToolbar(selection);
      } else {
        hideToolbar();
      }
    }, 80);
  }

  document.addEventListener('selectionchange', onSelectionChange);
  window.addEventListener('scroll', hideToolbar, true);
  window.addEventListener('resize', hideToolbar);
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') hideToolbar();
  });
})();
