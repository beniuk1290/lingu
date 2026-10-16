/**
 * LingoPilot – silnik automatycznej sesji InstaLing.
 *
 * Zasady działania:
 *  - pracuje wewnątrz strony (iniekcja z Flutter WebView),
 *  - odpowiada na pytania na podstawie trwałego słowniczka przekazanego z aplikacji,
 *  - wpisuje odpowiedzi ZNAK PO ZNAKU z losowymi opóźnieniami (jak człowiek),
 *    z okazjonalnymi przerwami na "namysł" i drobnymi literówkami z poprawką,
 *  - każde odsłonięte przez stronę tłumaczenie zapisuje się z powrotem do aplikacji,
 *  - komunikuje się z Flutterem przez window.flutter_inappwebview.callHandler('lpBotEvent', json).
 */
(function () {
  'use strict';

  // Silnik żyje w oknie strony. Przy ponownej iniekcji w tym samym dokumencie
  // (start/wznowienie/ładowanie) NIE tworzymy drugiej instancji z własną
  // pętlą – konfiguracja i tak jest wywoływana zaraz potem z aplikacji.
  if (window.__lpBot && typeof window.__lpBot.version === 'string') {
    return;
  }
  var VERSION = '1.1.0';

  // ---------- konfiguracja (domyślne wartości, nadawane z aplikacji) ----------
  var cfg = {
    lang: 'en',
    dict: {},
    autoLearn: true,
    autoStart: true,
    debug: false,
    typing: {
      min: 45, max: 140,          // ms na znak
      thinkMin: 250, thinkMax: 1100, // chwile "namysłu"
      typoRate: 0.03               // szansa literówki z poprawką
    },
    delays: {
      tickMin: 650, tickMax: 1700,  // pętla główna
      clickMin: 280, clickMax: 900, // po kliknięciu przycisku
      wordMin: 700, wordMax: 2200   // między słowami
    },
    errorRate: 0                    // celowo błędne odpowiedzi (0–0.3)
  };

  // ---------- stan ----------
  var running = false;
  var paused = false;
  var busy = false;
  var timer = null;
  var stats = { answered: 0, learned: 0, corrections: 0, startedAt: 0 };
  var lastLoginHintUrl = ''; // loginRequired raz na stronę logowania

  // ---------- pomocnicze ----------
  function $(sel, root) {
    try { return (root || document).querySelector(sel); } catch (e) { return null; }
  }

  function isVisible(el) {
    if (!el) return false;
    try {
      var st = window.getComputedStyle(el);
      if (st.display === 'none' || st.visibility === 'hidden') return false;
      return el.offsetParent !== null || el.getClientRects().length > 0;
    } catch (e) { return false; }
  }

  function txt(el) {
    if (!el) return '';
    return (el.innerText || el.textContent || '').replace(/\s+/g, ' ').trim();
  }

  function sleep(ms) {
    return new Promise(function (res) { setTimeout(res, Math.max(0, ms)); });
  }

  function rand(a, b) { return a + Math.random() * (b - a); }

  function emit(type, data) {
    var payload = data || {};
    payload.type = type;
    payload.ts = Date.now();
    payload.stats = {
      answered: stats.answered,
      learned: stats.learned,
      corrections: stats.corrections
    };
    try {
      if (window.flutter_inappwebview && typeof window.flutter_inappwebview.callHandler === 'function') {
        var p = window.flutter_inappwebview.callHandler('lpBotEvent', JSON.stringify(payload));
        if (p && typeof p.catch === 'function') { p.catch(function () {}); }
      }
    } catch (e) { /* brak mostka – pracujemy offline */ }
    if (cfg.debug && window.console) {
      console.log('[LingoPilot]', type, payload);
    }
  }

  function click(el) {
    if (!el) return false;
    try {
      if (typeof el.click === 'function') { el.click(); }
      else { el.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window })); }
      return true;
    } catch (e) {
      emit('log', { level: 'error', msg: 'click: ' + e });
      return false;
    }
  }

  function dispatchKey(input, type, key) {
    var init = { key: key, code: key.length === 1 ? 'Key' + key.toUpperCase() : key, bubbles: true, cancelable: true, view: window };
    try {
      if (key.length === 1) init.keyCode = key.toUpperCase().charCodeAt(0);
      else if (key === 'Backspace') init.keyCode = 8;
      else if (key === 'Enter') init.keyCode = 13;
      input.dispatchEvent(new KeyboardEvent(type, init));
    } catch (e) { /* starzy WebView bez konstruktorów – ignorujemy */ }
  }

  function dispatchInput(input, data, inputType) {
    try {
      if (typeof InputEvent === 'function') {
        input.dispatchEvent(new InputEvent('input', { bubbles: true, cancelable: false, data: data || '', inputType: inputType || 'insertText' }));
        return;
      }
    } catch (e) { /* fallback */ }
    input.dispatchEvent(new Event('input', { bubbles: true }));
  }

  function valueSetterFor(input) {
    var proto = (input.tagName === 'TEXTAREA') ? window.HTMLTextAreaElement.prototype : window.HTMLInputElement.prototype;
    var desc = Object.getOwnPropertyDescriptor(proto, 'value');
    return desc && desc.set ? desc.set : null;
  }

  function setValue(input, value) {
    var set = valueSetterFor(input);
    if (set) { set.call(input, value); }
    else { input.value = value; }
  }

  function typoChar(ch) {
    var code = ch.toLowerCase().charCodeAt(0);
    if (isNaN(code)) return ch;
    var delta = (Math.random() < 0.5 ? -1 : 1);
    var next = code + delta;
    if (next < 97 || next > 122) next = code - delta;
    var out = String.fromCharCode(next);
    return ch === ch.toUpperCase() ? out.toUpperCase() : out;
  }

  /**
   * Wpisywanie jak u człowieka: znak po znaku, z eventami klawiatury,
   * losową prędkością, chwilami namysłu i okazjonalną literówką z poprawką.
   */
  async function typeHuman(input, text) {
    if (!input || !text) return false;
    try { input.focus(); } catch (e) { /* ignore */ }
    var cur = '';
    for (var i = 0; i < text.length; i++) {
      var ch = text.charAt(i);
      var makeTypo = cfg.typing.typoRate > 0 &&
        Math.random() < cfg.typing.typoRate &&
        i > 0 && i < text.length - 1 &&
        /[a-zA-Ząćęłńóśźż]/.test(ch);

      if (makeTypo) {
        var wrong = typoChar(ch);
        cur += wrong;
        setValue(input, cur);
        dispatchKey(input, 'keydown', wrong);
        dispatchInput(input, wrong);
        dispatchKey(input, 'keyup', wrong);
        await sleep(rand(cfg.typing.min, cfg.typing.max));
        await sleep(rand(cfg.typing.thinkMin * 0.3, cfg.typing.thinkMax * 0.5)); // "o, literówka..."
        cur = cur.slice(0, -1);
        setValue(input, cur);
        dispatchKey(input, 'keydown', 'Backspace');
        dispatchInput(input, '', 'deleteContentBackward');
        dispatchKey(input, 'keyup', 'Backspace');
        await sleep(rand(cfg.typing.min, cfg.typing.max));
        stats.corrections++;
      }

      cur += ch;
      setValue(input, cur);
      dispatchKey(input, 'keydown', ch);
      dispatchInput(input, ch);
      dispatchKey(input, 'keyup', ch);
      await sleep(rand(cfg.typing.min, cfg.typing.max));

      // okazjonalna pauza na namysł; po spacji dłuższa przerwa
      if (Math.random() < 0.04) {
        await sleep(rand(cfg.typing.thinkMin, cfg.typing.thinkMax));
      } else if (ch === ' ') {
        await sleep(rand(cfg.typing.min * 2, cfg.typing.max * 5));
      }
    }
    return true;
  }

  // ---------- słowniczek ----------
  function lookup(prompt) {
    if (!prompt) return null;
    if (Object.prototype.hasOwnProperty.call(cfg.dict, prompt)) return cfg.dict[prompt];
    var lower = prompt.toLowerCase();
    for (var k in cfg.dict) {
      if (Object.prototype.hasOwnProperty.call(cfg.dict, k) && k.toLowerCase() === lower) return cfg.dict[k];
    }
    return null;
  }

  function learn(src, dst) {
    if (!src || !dst || src === dst) return false;
    if (cfg.dict[src] === dst) return false;
    cfg.dict[src] = dst;
    stats.learned++;
    emit('word', { src: src, dst: dst, lang: cfg.lang });
    return true;
  }

  function makeWrong(known, source) {
    // celowo błędna odpowiedź – strona odsłoni poprawną, którą się nauczymy
    var base = known || source || 'x';
    if (base.length > 3) return base.slice(0, base.length - 2);
    if (base.length > 1) return base.slice(0, 1);
    return base + '?';
  }

  // ---------- odczyt strony ----------
  function getPrompt() {
    var el = $('#question > div.word_data > div.translation') ||
      $('#question .translation') ||
      $('.word_data .translation');
    return txt(el);
  }

  function isLoginPage() {
    var pwd = $('input[type="password"]');
    return !!pwd && !$('#question');
  }

  // ---------- nawigacja po stronie InstaLing ----------

  /**
   * Znajduje na panelu ucznia link startujący sesję.
   * Pokrywa zmienny interfejs: #student_panel (starszy panel),
   * linki wprost do aplikacji sesji (app.php) i teksty przycisków
   * typu "Zacznij codzienną sesję" / "Dokończ sesję".
   */
  function findStartSessionLink() {
    var known = $('#student_panel a');
    if (isVisible(known)) return known;
    var hrefs = document.querySelectorAll('a[href*="app.php"]');
    for (var i = 0; i < hrefs.length; i++) {
      if (isVisible(hrefs[i])) return hrefs[i];
    }
    var re = /^(zacznij|rozpocznij|dokończ|dokoncz|kontynuuj|kontynuowanie|wznów|wznow)/i;
    var all = document.querySelectorAll('a, button, [role="button"]');
    for (var j = 0; j < all.length; j++) {
      var el = all[j];
      if (!isVisible(el)) continue;
      var t = txt(el);
      if (t.length < 4 || t.length > 80) continue;
      if (re.test(t) && /sesj/i.test(t)) return el;
    }
    return null;
  }

  /** Link "Zaloguj się" w menu – wejście na stronę logowania ze strony głównej. */
  function findLoginLink() {
    var cands = document.querySelectorAll(
      'nav a[href*="login"], a[href="/login"], a[href*="/login"], a[href*="page=login"]');
    for (var i = 0; i < cands.length; i++) {
      if (isVisible(cands[i]) && /zaloguj/i.test(txt(cands[i]))) return cands[i];
    }
    var all = document.querySelectorAll('a, button, [role="button"]');
    for (var j = 0; j < all.length; j++) {
      var el = all[j];
      if (isVisible(el) && /^zaloguj/i.test(txt(el))) return el;
    }
    return null;
  }

  // ---------- obsługa stanów strony ----------
  async function handleNewWord() {
    emit('state', { state: 'newWord' });
    var prompt = getPrompt();
    var word = txt($('#word'));
    if (cfg.autoLearn && prompt && word && prompt.toLowerCase() !== word.toLowerCase()) {
      learn(prompt, word);
    }
    await sleep(rand(cfg.delays.wordMin, cfg.delays.wordMax));
    var dontKnow = $('#dont_know_new');
    if (dontKnow) {
      click(dontKnow);
      await sleep(rand(cfg.delays.clickMin, cfg.delays.clickMax));
    }
    var skip = $('#skip');
    if (isVisible(skip)) click(skip);
    await sleep(rand(cfg.delays.clickMin, cfg.delays.clickMax));
  }

  async function handleAnswerPage() {
    emit('state', { state: 'revealing' });
    var prompt = getPrompt();
    var correct = txt($('#word'));
    if (cfg.autoLearn && prompt && correct && prompt.toLowerCase() !== correct.toLowerCase()) {
      learn(prompt, correct);
    }
    await sleep(rand(cfg.delays.wordMin * 0.6, cfg.delays.wordMax));
    click($('#nextword'));
    await sleep(rand(cfg.delays.clickMin, cfg.delays.clickMax));
  }

  async function handleQuestion(prompt, input) {
    emit('state', { state: 'answering', prompt: prompt });
    var known = lookup(prompt);
    var intentional = cfg.errorRate > 0 && known && Math.random() < cfg.errorRate;
    var answer;
    if (known && !intentional) {
      answer = known;
    } else {
      answer = makeWrong(known, prompt);
    }

    await typeHuman(input, answer);
    await sleep(rand(cfg.delays.clickMin, cfg.delays.clickMax)); // chwila na "przeczytanie"
    click($('#check'));
    stats.answered++;
    emit('progress', {});
    await sleep(rand(cfg.delays.wordMin * 0.4, cfg.delays.wordMax * 0.7));
  }

  async function step() {
    if (!document.body) return;

    if (isLoginPage()) {
      // podpowiedź o logowaniu tylko raz na daną stronę (bez spamu w dzienniku)
      if (lastLoginHintUrl !== window.location.href) {
        lastLoginHintUrl = window.location.href;
        emit('loginRequired', {});
      }
      return;
    }

    var body = document.body.innerText || '';
    var ended = (body.indexOf('Gratulacje') !== -1 && body.indexOf('Powrót na stronę główną') !== -1) ||
      (isVisible($('#session_result')) && !$('#question'));
    if (ended) {
      emit('sessionEnd', { durationMs: Date.now() - stats.startedAt });
      stopInternal(false);
      return;
    }

    if (isVisible($('#loading'))) { emit('state', { state: 'loading' }); return; }

    if (isVisible($('#continue_session_page'))) {
      emit('log', { msg: 'kontynuacja sesji' });
      click($('#continue_session_button'));
      await sleep(rand(cfg.delays.clickMin, cfg.delays.clickMax));
      return;
    }

    if (isVisible($('#start_session_page'))) {
      emit('state', { state: 'starting' });
      click($('#start_session_button'));
      await sleep(rand(cfg.delays.clickMin, cfg.delays.clickMax));
      return;
    }

    if (isVisible($('#new_word_form'))) {
      await handleNewWord();
      return;
    }

    if (isVisible($('#answer_page'))) {
      await handleAnswerPage();
      return;
    }

    var prompt = getPrompt();
    var input = $('#answer');
    if (prompt && input) {
      await handleQuestion(prompt, input);
      return;
    }

    // panel ucznia: "Zacznij codzienną sesję" / "Dokończ sesję" → aplikacja sesji
    var startLink = findStartSessionLink();
    if (startLink) {
      emit('log', { msg: 'przechodzę do sesji: ' + txt(startLink).slice(0, 60) });
      click(startLink);
      await sleep(rand(cfg.delays.clickMin, cfg.delays.clickMax));
      return;
    }

    // strona główna (marketing) – otwórz stronę logowania
    var path = window.location.pathname || '/';
    if (path === '/' || path === '/index.php' || path === '/index.html') {
      var loginLink = findLoginLink();
      if (loginLink) {
        emit('log', { msg: 'otwieram stronę logowania' });
        click(loginLink);
        await sleep(rand(cfg.delays.clickMin, cfg.delays.clickMax));
        return;
      }
    }

    emit('idle', { url: window.location.href });
  }

  // ---------- pętla ----------
  async function tick() {
    if (!running) return;
    if (paused || busy) {
      timer = setTimeout(tick, paused ? 300 : 250);
      return;
    }
    busy = true;
    try {
      await step();
    } catch (e) {
      emit('log', { level: 'error', msg: String((e && e.stack) || e) });
    }
    busy = false;
    if (running) {
      timer = setTimeout(tick, rand(cfg.delays.tickMin, cfg.delays.tickMax));
    }
  }

  function stopInternal(emitEvent) {
    running = false;
    paused = false;
    busy = false;
    if (timer) { clearTimeout(timer); timer = null; }
    if (emitEvent !== false) emit('state', { state: 'stopped' });
  }

  // ---------- API dla Fluttera ----------
  window.__lpBot = {
    version: VERSION,
    configure: function (next) {
      try {
        var parsed = (typeof next === 'string') ? JSON.parse(next) : next;
        if (!parsed) return false;
        if (parsed.typing) {
          for (var t in parsed.typing) { if (parsed.typing.hasOwnProperty(t)) cfg.typing[t] = parsed.typing[t]; }
        }
        if (parsed.delays) {
          for (var d in parsed.delays) { if (parsed.delays.hasOwnProperty(d)) cfg.delays[d] = parsed.delays[d]; }
        }
        if (parsed.lang) cfg.lang = parsed.lang;
        if (typeof parsed.autoLearn === 'boolean') cfg.autoLearn = parsed.autoLearn;
        if (typeof parsed.debug === 'boolean') cfg.debug = parsed.debug;
        if (typeof parsed.errorRate === 'number') cfg.errorRate = parsed.errorRate;
        if (parsed.dict) {
          var added = 0;
          for (var k in parsed.dict) {
            if (parsed.dict.hasOwnProperty(k) && cfg.dict[k] !== parsed.dict[k]) { added++; }
          }
          // słownik z aplikacji jest źródłem prawdy przy starcie sesji
          cfg.dict = parsed.dict;
          emit('log', { msg: 'konfiguracja OK, słów: ' + Object.keys(cfg.dict).length + ' (nowe: ' + added + ')' });
        }
        emit('ready', { version: VERSION, dictSize: Object.keys(cfg.dict).length, lang: cfg.lang });
        return true;
      } catch (e) {
        emit('log', { level: 'error', msg: 'configure: ' + e });
        return false;
      }
    },
    start: function () {
      if (running) return true;
      running = true;
      paused = false;
      stats.startedAt = Date.now();
      emit('state', { state: 'running' });
      timer = setTimeout(tick, rand(cfg.delays.tickMin, cfg.delays.tickMax));
      return true;
    },
    pause: function () { paused = true; emit('state', { state: 'paused' }); return true; },
    resume: function () { if (running) { paused = false; emit('state', { state: 'running' }); } return true; },
    stop: function () { stopInternal(true); return true; },
    learn: function (src, dst) { return learn(src, dst); },
    getState: function () {
      return {
        version: VERSION, running: running, paused: paused,
        lang: cfg.lang, dictSize: Object.keys(cfg.dict).length, stats: stats
      };
    },
    destroy: function () { stopInternal(false); delete window.__lpBot; }
  };

  emit('ready', { version: VERSION, dictSize: Object.keys(cfg.dict).length, lang: cfg.lang });
})();
