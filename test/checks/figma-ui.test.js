const assert = require('node:assert/strict');
const { createHash } = require('node:crypto');
const fs = require('node:fs');
const vm = require('node:vm');
const test = require('node:test');
const { environment } = require('./figma-fixture.cjs');

const library = fs.readFileSync('test/figma/vendor/js-sha256/sha256.js', 'utf8');
const html = fs.readFileSync('test/figma/ui.html', 'utf8')
  .replace('/* DOGlyad_SHA256_BUNDLE */', library)
  .replace('/* DOGlyad_BRIDGE_KEY */', JSON.stringify('test-token'));
const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];

function browser({ corruptImage = false, changeManifest = false, rejectAck = false, offline = false } = {}) {
  const plugin = environment({ managed: false, pageLimit: true });
  const elements = {
    import: { disabled: false },
    status: { textContent: '' }
  };
  const bytes = Buffer.from([137, 80, 78, 71, 0, 128, 255, 1, 2, 3]);
  const digest = createHash('sha256').update(bytes).digest('hex');
  plugin.manifest.images.forEach(image => { image.sha256 = digest; });
  const requests = [];
  const acknowledgments = [];
  let manifests = 0;
  const timers = new Map();
  let timerId = 0;
  const controls = { offline };
  const context = vm.createContext({
    crypto: {}, // Figma's sandbox has no crypto.subtle.
    setTimeout: (callback, delay) => {
      if (delay === 60000) return setTimeout(callback, delay);
      const id = ++timerId;
      timers.set(id, callback);
      return id;
    },
    clearTimeout: id => { timers.delete(id); clearTimeout(id); },
    Uint8Array, ArrayBuffer, TypeError,
    document: { getElementById: id => elements[id] },
    fetch: async (url, options) => {
      if (controls.offline) throw new TypeError('Failed to fetch');
      assert.equal(options.headers.Authorization, 'Bearer test-token');
      assert.equal(options.headers['X-Doglyad-Regression-Protocol'], '10');
      assert.ok(url.startsWith('http://localhost:8765/'));
      requests.push(url);
      if (url.endsWith('/manifest')) {
        manifests++;
        const result = JSON.parse(JSON.stringify(plugin.manifest));
        if (changeManifest && manifests > 1) result.suiteHash = 'changed';
        return { ok: true, json: async () => result };
      }
      if (url.includes('/image/')) {
        const response = Uint8Array.from(bytes);
        if (corruptImage) response[0] ^= 1;
        return { ok: true, arrayBuffer: async () => response.buffer };
      }
      assert.ok(url.endsWith('/ack'));
      acknowledgments.push(JSON.parse(options.body));
      return { ok: !rejectAck, status: rejectAck ? 503 : 200 };
    },
    parent: { postMessage: ({ pluginMessage }) => plugin.figma.ui.onmessage(pluginMessage) }
  });
  context.window = context;
  plugin.figma.ui.postMessage = message => {
    plugin.messages.push(message);
    context.window.onmessage({ data: { pluginMessage: message } });
  };
  vm.runInContext(script, context);
  const poll = async () => {
    const entry = timers.entries().next().value;
    assert.ok(entry, 'automatic polling must be scheduled');
    timers.delete(entry[0]);
    await entry[1]();
  };
  return { plugin, elements, context, requests, acknowledgments, poll, controls };
}

test('bundled SHA-256 matches independent known vectors without Web Crypto', () => {
  const { context } = browser();
  assert.equal(context.crypto.subtle, undefined);
  for (const input of ['', 'abc', 'a'.repeat(1000000)]) {
    assert.equal(context.sha256(input), createHash('sha256').update(input).digest('hex'));
  }
  for (const length of [1, 55, 56, 63, 64, 65, 127, 128, 4096]) {
    const input = Uint8Array.from({ length }, (_, index) => index % 256);
    assert.equal(context.sha256(input), createHash('sha256').update(input).digest('hex'));
  }
});

test('open plugin imports automatically without token entry, Web Crypto or new pages', async () => {
  const e = browser();
  await e.poll();
  assert.match(e.elements.status.textContent, /Обновлено 2 снимков/);
  assert.equal(e.acknowledgments.length, 1);
  assert.equal(e.acknowledgments[0].imageCount, 2);
  assert.equal(e.plugin.manual.removed, true);
  assert.equal(e.plugin.figma.root.children.length, 3);
  assert.equal(e.elements.import.disabled, false);
});

test('open plugin waits for the bridge, imports a run, then automatically accepts the next run', async () => {
  const e = browser({ offline: true });
  await e.poll();
  assert.match(e.elements.status.textContent, /Ожидание успешного прогона/);
  assert.equal(e.acknowledgments.length, 0);
  e.controls.offline = false;
  await e.poll();
  assert.equal(e.acknowledgments.length, 1);
  e.controls.offline = true;
  await e.poll();
  assert.match(e.elements.status.textContent, /Ожидание следующего прогона/);
  e.plugin.manifest.runId = 'next-run';
  e.controls.offline = false;
  await e.poll();
  assert.equal(e.acknowledgments.length, 2);
  assert.equal(e.acknowledgments[1].runId, 'next-run');
});

test('a corrupt PNG aborts before image creation and acknowledgment', async () => {
  const e = browser({ corruptImage: true });
  await e.elements.import.onclick();
  assert.match(e.elements.status.textContent, /Контрольная сумма снимка не совпала/);
  assert.equal(e.plugin.messages.some(message => message.type === 'received'), false);
  assert.equal(e.acknowledgments.length, 0);
  assert.equal(e.plugin.manual.removed, false);
  assert.equal(e.plugin.page.getPluginData('doglyadRegression'), '');
});

test('a changed manifest aborts before replacing the collection', async () => {
  const e = browser({ changeManifest: true });
  await e.elements.import.onclick();
  assert.match(e.elements.status.textContent, /Прогон изменился/);
  assert.equal(e.acknowledgments.length, 0);
  assert.equal(e.plugin.manual.removed, false);
  assert.equal(e.plugin.page.getPluginData('doglyadRegression'), '');
});

test('a failed acknowledgment can be retried without duplicating a completed collection', async () => {
  const e = browser({ rejectAck: true });
  await e.elements.import.onclick();
  const imageRequests = e.requests.filter(url => url.includes('/image/')).length;
  await e.elements.import.onclick();
  assert.equal(e.acknowledgments.length, 2);
  assert.equal(e.requests.filter(url => url.includes('/image/')).length, imageRequests);
  assert.equal(e.acknowledgments[0].nodeId, e.acknowledgments[1].nodeId);
  assert.match(e.elements.status.textContent, /503/);
});
