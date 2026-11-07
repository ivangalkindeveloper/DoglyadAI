const assert = require('node:assert/strict');
const test = require('node:test');
const { environment } = require('./figma-fixture.cjs');

test('a failed run does not mutate the previous collection', async () => {
  const e = environment(); e.manifest.status = 'failed';
  await e.figma.ui.onmessage({ type: 'begin', manifest: e.manifest });
  assert.equal(e.messages.at(-1).type, 'error');
  assert.equal(e.page.children.length, 2);
  assert.equal(e.old.removed, false);
});

test('an interrupted image transfer preserves previous and manual nodes', async () => {
  const e = environment();
  await e.figma.ui.onmessage({ type: 'begin', manifest: e.manifest });
  await e.figma.ui.onmessage({ type: 'image', id: 'one', bytes: [1] });
  assert.equal(e.old.removed, false);
  await e.figma.ui.onmessage({ type: 'commit' });
  assert.equal(e.messages.at(-1).type, 'error');
  assert.equal(e.old.removed, false);
  assert.equal(e.manual.removed, false);
});

test('complete transfer clears every old node on the regression page', async () => {
  const e = environment();
  await e.figma.ui.onmessage({ type: 'begin', manifest: e.manifest });
  for (const id of ['one', 'two']) await e.figma.ui.onmessage({ type: 'image', id, bytes: [1] });
  assert.equal(e.old.removed, false);
  await e.figma.ui.onmessage({ type: 'commit' });
  assert.equal(e.old.removed, true);
  assert.equal(e.manual.removed, true);
  assert.equal(e.page.children.length, 1);
  assert.equal(e.messages.at(-1).type, 'done');
  assert.equal(e.messages.at(-1).imageCount, 2);
});

test('a different Figma file cannot receive the run', async () => {
  const e = environment(); e.figma.fileKey = 'other';
  await e.figma.ui.onmessage({ type: 'begin', manifest: e.manifest });
  assert.equal(e.messages.at(-1).type, 'error');
  assert.equal(e.page.children.length, 2);
});

test('coverage gaps are visible without blocking a fully successful execution', async () => {
  const e = environment();
  e.manifest.coverage = { missingExecution: [{ id: 'ScanSpeech.record' }] };
  await e.figma.ui.onmessage({ type: 'begin', manifest: e.manifest });
  assert.equal(e.messages.at(-1).type, 'ready');
  assert.equal(e.page.children.at(-1).name, 'Regression · new · 1 сценариев требуют автоматизации');
});

test('first import clears only the target page and works at the page limit', async () => {
  const e = environment({ managed: false, pageLimit: true });
  await e.figma.ui.onmessage({ type: 'begin', manifest: e.manifest });
  assert.equal(e.messages.at(-1).type, 'ready');
  assert.equal(e.figma.root.children.length, 3);
  const collection = e.page.children.at(-1);
  assert.equal(collection.x, 0);
  assert.equal(collection.y, 0);
  assert.equal(e.page.getPluginData('doglyadRegression'), '');
  for (const id of ['one', 'two']) await e.figma.ui.onmessage({ type: 'image', id, bytes: [1] });
  await e.figma.ui.onmessage({ type: 'commit' });
  assert.equal(e.messages.at(-1).type, 'done');
  assert.equal(e.manual.removed, true);
  assert.ok(e.figma.root.children.every(page => !page.removed));
  assert.equal(e.page.children.length, 1);
  assert.equal(e.page.name, 'User designs');
  assert.equal(e.page.getPluginData('doglyadRegression'), '1');
});

test('an interrupted first import does not claim or remove the current page', async () => {
  const e = environment({ managed: false, pageLimit: true });
  await e.figma.ui.onmessage({ type: 'begin', manifest: e.manifest });
  const collection = e.page.children.at(-1);
  await e.figma.ui.onmessage({ type: 'abort' });
  assert.equal(collection.removed, true);
  assert.equal(e.manual.removed, false);
  assert.equal(e.page.getPluginData('doglyadRegression'), '');
  assert.equal(e.figma.root.children.length, 3);
});

test('replacement starts at the cleared page origin', async () => {
  const e = environment();
  await e.figma.ui.onmessage({ type: 'begin', manifest: e.manifest });
  const collection = e.page.children.at(-1);
  assert.equal(collection.x, 0);
  assert.equal(collection.y, 0);
});

test('Preview precedes regression with quadrupled gap, transparent frames, white text and correct module names', async () => {
  const e = environment();
  e.manifest.runId = '20261107T104711Z-8c97df65';
  const samples = [
    ['bootstrap--001-OnBoarding-welcome', 'bootstrap', 'OnBoarding'],
    ['bootstrap--003-Paywall-initial', 'bootstrap', 'OnBoarding'],
    ['atlas-paywall--003-Paywall-pro', 'atlas-paywall', 'Paywall'],
    ['atlas-onboarding--001-OnBoarding-welcome', 'atlas-onboarding', 'OnBoarding'],
    ['atlas-onboarding--002-OnBoarding-legal', 'atlas-onboarding', 'OnBoarding'],
    ['bootstrap--000-ApplicationSplash-initial', 'bootstrap', 'OnBoarding'],
  ];
  e.manifest.images = samples.map(([id, caseId, screen]) => ({ id, caseId, screen, state: id, width: 390, height: 844 }));
  e.manifest.expectedScreenshots = samples.length;
  e.manifest.coverage = { modules: [{ module: 'OnBoarding' }, { module: 'Paywall' }] };
  await e.figma.ui.onmessage({ type: 'begin', manifest: e.manifest });
  for (const [id] of samples) await e.figma.ui.onmessage({ type: 'image', id, bytes: [1] });
  await e.figma.ui.onmessage({ type: 'commit' });
  assert.equal(e.messages.at(-1).type, 'done');
  const collection = e.page.children.at(-1);
  assert.equal(collection.name, 'Regression · 20261107T104711Z');
  assert.equal(collection.getPluginData('doglyadRegressionRun'), e.manifest.runId);
  assert.equal(collection.itemSpacing, 1920);
  assert.deepEqual(collection.children.map(n => n.name), ['Preview', 'Регресс']);
  const [previews, regression] = collection.children;
  assert.equal(previews.itemSpacing, 40);
  assert.equal(regression.itemSpacing, 40);
  assert.deepEqual(previews.children.slice(1).map(n => n.name), ['Preview / OnBoarding', 'Preview / Paywall']);
  assert.deepEqual(regression.children.slice(1).map(n => n.name), ['Регресс / ApplicationSplash', 'Регресс / OnBoarding', 'Регресс / Paywall']);
  const row = previews.children[1].children[1];
  assert.equal(row.layoutMode, 'HORIZONTAL');
  assert.equal(row.itemSpacing, 20);
  assert.equal(row.children.length, 2);
  const inspect = node => {
    if (node.layoutMode) {
      assert.equal(node.fills.length, 0);
      assert.equal(node.clipsContent, false);
    }
    if (typeof node.characters === 'string') {
      assert.equal(node.fills.length, 1);
      assert.equal(JSON.stringify(node.fills[0]), JSON.stringify({ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }));
    }
    node.children.forEach(inspect);
  };
  inspect(collection);
});

test('preview cards sort numerically before images arrive; regression retains scenario order', async () => {
  const e = environment();
  const samples = [
    { id: 'e2e--B-first', kind: 'functional', module: 'B', state: 'first', displayOrder: 1 },
    { id: 'atlas-b--10-B-last', kind: 'render', module: 'B', state: '10 Last' },
    { id: 'atlas-b--2-B-middle', kind: 'render', module: 'B', state: '2 Middle' },
    { id: 'atlas-b--1-B-first', kind: 'render', module: 'B', state: '1 First' },
    { id: 'e2e--B-second', kind: 'functional', module: 'B', state: 'second', displayOrder: 2 },
  ];
  e.manifest.images = samples.map(image => ({...image, width: 390, height: 844}));
  e.manifest.expectedScreenshots = samples.length;
  await e.figma.ui.onmessage({ type: 'begin', manifest: e.manifest });
  for (const {id} of samples) await e.figma.ui.onmessage({ type: 'image', id, bytes: [1] });
  await e.figma.ui.onmessage({ type: 'commit' });
  const [preview, regression] = e.page.children[0].children;
  const cards = section => section.children[1].children[1].children;
  assert.deepEqual(cards(preview).map(n => n.children[1].name), [samples[3].id, samples[2].id, samples[1].id]);
  assert.deepEqual(cards(regression).map(n => n.children[1].name), [samples[0].id, samples[4].id]);
});

test('same run is rebuilt after a layout upgrade, then reused on acknowledgment retry', async () => {
  const e = environment();
  e.old.setPluginData('doglyadRegressionRun', e.manifest.runId);
  e.old.setPluginData('suiteHash', e.manifest.suiteHash);
  await e.figma.ui.onmessage({ type: 'begin', manifest: e.manifest });
  assert.equal(e.messages.at(-1).type, 'ready');
  for (const id of ['one', 'two']) await e.figma.ui.onmessage({ type: 'image', id, bytes: [1] });
  await e.figma.ui.onmessage({ type: 'commit' });
  const first = e.messages.at(-1);
  assert.equal(e.old.removed, true);
  await e.figma.ui.onmessage({ type: 'begin', manifest: e.manifest });
  assert.equal(e.messages.at(-1).type, 'done');
  assert.equal(e.messages.at(-1).nodeId, first.nodeId);
});

test('historical English previews are validated but omitted from the Russian collection', async () => {
  const e = environment();
  e.manifest.images = [
    { id: 'ru', caseId: 'atlas-paywall', kind: 'render', module: 'Paywall', state: '04 Русский', width: 390, height: 844 },
    { id: 'en', caseId: 'atlas-paywall', kind: 'render', module: 'Paywall', state: '05 English', width: 390, height: 844 },
    { id: 'en-management', caseId: 'atlas-manage', kind: 'render', module: 'ManageSubscription', state: '08 Pro · English', width: 390, height: 844 },
    { id: 'functional', caseId: 'e2e', kind: 'functional', module: 'Paywall', state: '05 English', width: 390, height: 844 },
  ];
  e.manifest.expectedScreenshots = 4;
  await e.figma.ui.onmessage({ type: 'begin', manifest: e.manifest });
  await e.figma.ui.onmessage({ type: 'image', id: 'ru', bytes: [1] });
  await e.figma.ui.onmessage({ type: 'commit' });
  assert.equal(e.messages.at(-1).type, 'error');
  assert.equal(e.old.removed, false);
  await e.figma.ui.onmessage({ type: 'begin', manifest: e.manifest });
  for (const { id } of e.manifest.images) await e.figma.ui.onmessage({ type: 'image', id, bytes: [1] });
  await e.figma.ui.onmessage({ type: 'commit' });
  const receipt = e.messages.at(-1);
  assert.equal(receipt.type, 'done');
  assert.equal(receipt.imageCount, 4);
  assert.equal(receipt.visibleImageCount, 2);
  const [previews, regression] = e.page.children[0].children;
  assert.equal(previews.children[1].children[1].children.length, 1);
  assert.equal(regression.children[1].children[1].children.length, 1);
  assert.equal(previews.children[1].children[1].children[0].name, 'Preview · Paywall · 01 Русский');
});
