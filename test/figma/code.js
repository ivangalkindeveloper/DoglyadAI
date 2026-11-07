/* Verify and stage all images, then clear the regression page before showing the new collection. */
figma.showUI(__html__, { width: 420, height: 220 });
const layoutVersion = 'ordered-white-text-v6';
let stage = null;
let manifest = null;
let received = new Set();
let target = null;
let previous = [];
let imageCards = new Map();

function frame(parent, name, direction, spacing) {
  const node = figma.createFrame();
  parent.appendChild(node);
  node.name = name;
  node.layoutMode = direction;
  node.primaryAxisSizingMode = 'AUTO';
  node.counterAxisSizingMode = 'AUTO';
  node.itemSpacing = spacing;
  node.fills = [];
  node.clipsContent = false;
  return node;
}

function text(parent, value, size, width = 1200) {
  const label = figma.createText();
  label.fontName = { family: 'Inter', style: 'Regular' };
  label.characters = value;
  label.fontSize = size;
  label.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }];
  label.resize(width, size * 2);
  label.textAutoResize = 'HEIGHT';
  parent.appendChild(label);
}

function imageGroup(image) {
  const kind = image.kind === 'render' || (image.caseId || image.id).startsWith('atlas-')
    ? 'Preview' : 'Регресс';
  // Older reports used the case's module for every image, even when a flow
  // visited several screens. Screenshot names retain the actual screen name.
  const shot = image.id.includes('--') ? image.id.split('--')[1] : '';
  const match = shot.match(/^(?:\d+-)?([A-Za-z][A-Za-z0-9_]+)-/);
  const module = image.module || (match && match[1]) || image.screen;
  return { kind, module, shot };
}

function visibleImage(image) {
  // Historical successful runs retain their English captures as evidence.
  // The requested collection now displays Russian previews only.
  return imageGroup(image).kind !== 'Preview'
    || (image.locale !== 'en' && !/^\d+ (?:Pro · )?English$/.test(image.state));
}

function prepareRows(value) {
  const order = ['ApplicationSplash', ...((value.coverage || {}).modules || []).map(m => m.module)];
  for (const kind of ['Preview', 'Регресс']) {
    const images = value.images.filter(image => visibleImage(image) && imageGroup(image).kind === kind);
    if (!images.length) continue;
    const section = frame(stage, kind, 'VERTICAL', 40);
    text(section, `${kind} · ${images.length} снимков`, 40);
    const modules = [...new Set(images.map(image => imageGroup(image).module))];
    modules.sort((a, b) => {
      const rank = name => order.includes(name) ? order.indexOf(name) : order.length;
      return rank(a) - rank(b);
    });
    for (const module of modules) {
      const group = frame(section, `${kind} / ${module}`, 'VERTICAL', 32);
      text(group, module, 28);
      const row = frame(group, `${module} · экраны`, 'HORIZONTAL', 20);
      const ordered = images.filter(item => imageGroup(item).module === module);
      const rank = image => {
        if (Number.isInteger(image.displayOrder)) return image.displayOrder;
        const number = kind === 'Preview' && image.state.match(/^(\d+) /);
        return number ? Number(number[1]) : value.images.indexOf(image);
      };
      ordered.sort((a, b) => rank(a) - rank(b));
      for (const [index, image] of ordered.entries()) {
        const group = imageGroup(image);
        const title = kind === 'Preview'
          ? image.state.replace(/^\d+ /, `${String(index + 1).padStart(2, '0')} `)
          : group.shot || image.state;
        const card = frame(row, `${kind} · ${module} · ${title}`, 'VERTICAL', 16);
        text(card, `${kind} · ${title}`, 16, 390);
        imageCards.set(image.id, card);
      }
    }
  }
}

function rollback() {
  if (stage && !stage.removed) stage.remove();
  stage = null;
  manifest = null;
  received = new Set();
  imageCards = new Map();
}

function focusCollection(collection) {
  const section = collection.children[0];
  const firstModule = section && section.children[1];
  figma.viewport.scrollAndZoomIntoView([firstModule || section || collection]);
}

async function handle(message) {
  if (message.type === 'begin') {
    rollback();
    const value = message.manifest;
    if (value.status !== 'passed' || !value.images.length || value.images.length !== value.expectedScreenshots
        || value.expectedCases.length !== value.results.length || value.results.some(r => r.exitCode !== 0)
        || value.results.some((r, i) => r.id !== value.expectedCases[i])) {
      throw new Error('The complete regression suite must pass before import.');
    }
    if (!figma.fileKey || figma.fileKey !== value.figmaFileKey) {
      throw new Error('Open the Figma file configured in test/secrets/config.local.json.');
    }
    await figma.loadAllPagesAsync();
    target = figma.root.children.find(p => p.getPluginData('doglyadRegression') === '1')
      || figma.currentPage;
    previous = target.children.filter(n => n.getPluginData('doglyadRegressionRun') && n.getPluginData('complete') === '1');
    const existing = previous.find(n => n.getPluginData('doglyadRegressionRun') === value.runId
      && n.getPluginData('suiteHash') === value.suiteHash
      && n.getPluginData('layoutVersion') === layoutVersion);
    if (existing) {
      await figma.setCurrentPageAsync(target);
      focusCollection(existing);
      figma.ui.postMessage({ type: 'done', runId: value.runId, fileKey: figma.fileKey,
        nodeId: existing.id, imageCount: value.images.length,
        visibleImageCount: value.images.filter(visibleImage).length, layoutVersion });
      return;
    }
    manifest = value;
    stage = frame(target, '', 'VERTICAL', 1920);
    stage.x = 0;
    stage.y = 0;
    const gaps = value.coverage && value.coverage.missingExecution
      ? value.coverage.missingExecution.length : 0;
    const runTitle = value.runId.replace(/^(\d{8}T\d{6}Z)-[0-9a-f]{8}$/, '$1');
    stage.name = `${value.figmaPageName || 'Doglyad Regression'} · ${runTitle}`
      + (gaps ? ` · ${gaps} сценариев требуют автоматизации` : '');
    stage.visible = false;
    stage.setPluginData('doglyadRegressionRun', value.runId);
    stage.setPluginData('suiteHash', value.suiteHash);
    stage.setPluginData('layoutVersion', layoutVersion);
    await figma.loadFontAsync({ family: 'Inter', style: 'Regular' });
    prepareRows(value);
    figma.ui.postMessage({ type: 'ready' });
  } else if (message.type === 'image') {
    if (!stage || !manifest) throw new Error('No pending run.');
    const expected = manifest.images[received.size];
    if (!expected || expected.id !== message.id || received.has(message.id)) throw new Error('Wrong image order.');
    if (!imageCards.has(expected.id)) {
      received.add(message.id);
      figma.ui.postMessage({ type: 'received', id: message.id });
      return;
    }
    const image = figma.createImage(new Uint8Array(message.bytes));
    const row = imageCards.get(expected.id);
    const rectangle = figma.createRectangle();
    rectangle.name = expected.id;
    rectangle.resize(390, expected.height * 390 / expected.width);
    rectangle.fills = [{ type: 'IMAGE', scaleMode: 'FIT', imageHash: image.hash }];
    row.appendChild(rectangle);
    received.add(message.id);
    figma.ui.postMessage({ type: 'received', id: message.id });
  } else if (message.type === 'commit') {
    if (!manifest || !stage || received.size !== manifest.images.length) throw new Error('Some images are missing.');
    await figma.setCurrentPageAsync(target);
    // The user dedicates this page to regression: remove every previous node,
    // including manual additions. Other pages are outside the publication target.
    for (const node of [...target.children]) if (node !== stage) node.remove();
    stage.visible = true;
    focusCollection(stage);
    stage.setPluginData('complete', '1');
    target.setPluginData('doglyadRegression', '1');
    const receipt = { type: 'done', runId: manifest.runId, fileKey: figma.fileKey,
      nodeId: stage.id, imageCount: received.size, visibleImageCount: imageCards.size, layoutVersion };
    stage = null;
    manifest = null;
    figma.ui.postMessage(receipt);
  } else if (message.type === 'abort') {
    rollback();
  }
}

figma.ui.onmessage = async message => {
  try { await handle(message); }
  catch (error) { rollback(); figma.ui.postMessage({ type: 'error', message: String(error.message || error) }); }
};
figma.on('close', rollback);
