/* Verify and stage all images, then clear the regression page before showing the new collection. */
figma.showUI(__html__, { width: 210, height: 110 });
const layoutVersion = 'iphone17-screen-v10';
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

// iPhone18,3 (iPhone 17), CoreSimulator framebufferMask
// 4E5532ED-1470-47D1-BDF4-7AA90C26957A: 1206 x 2622 px.
// Use Apple's continuous screen outline instead of approximating it with circular corners.
const iphone17Outline = 'M 952.014 0 C 968.0447 0 984.0706 0.048 1000.1 0.641 C 1018.459 1.321 1036.611 2.714 1054.731 6.09 C 1091.305 12.908 1124.57 27.704 1151.434 54.568 C 1178.301 81.434 1193.097 114.704 1199.912 151.282 C 1203.286 169.388 1204.678 187.528 1205.359 205.874 C 1205.948 221.75 1206 237.623 1206 253.5 L 1206 2368.5 C 1206 2384.377 1205.948 2400.2496 1205.359 2416.1255 C 1204.678 2434.4718 1203.286 2452.6118 1199.912 2470.718 C 1193.097 2507.2957 1178.301 2540.56555 1151.434 2567.43188 C 1124.57 2594.29595 1091.305 2609.09221 1054.731 2615.90938 C 1036.611 2619.285844 1018.459 2620.678804 1000.1 2621.358379 C 984.0706 2621.952022 968.0447 2622 952.014 2622 L 253.986 2622 C 237.9553 2622 221.9294 2621.952022 205.9001 2621.358379 C 187.5414 2620.678804 169.3889 2619.285844 151.2692 2615.90938 C 114.695 2609.09221 81.42958 2594.29595 54.56551 2567.43188 C 27.69918 2540.56555 12.90292 2507.2957 6.088003 2470.718 C 2.713793 2452.6118 1.32196 2434.4718 0.641258 2416.1255 C 0.051842 2400.2496 0 2384.377 0 2368.5 L 0 253.5 C 0 237.623 0.051842 221.75 0.641258 205.874 C 1.32196 187.528 2.713793 169.388 6.088003 151.282 C 12.90292 114.704 27.69918 81.434 54.56551 54.568 C 81.42958 27.704 114.695 12.908 151.2692 6.09 C 169.3889 2.714 187.5414 1.321 205.9001 0.641 C 221.9294 0.048 237.9553 0 253.986 0 L 952.014 0 Z';

function screenImage(name, width, height, fills) {
  const scale = width / 1206;
  let coordinate = 0;
  const data = iphone17Outline.replace(/-?\d+(?:\.\d+)?/g, value => {
    const number = Number(value);
    // Keep corner geometry proportional to width and anchor bottom corners to the bottom edge.
    const scaled = coordinate++ % 2 === 0 ? number * scale
      : number < 1311 ? number * scale : height - (2622 - number) * scale;
    return String(scaled);
  });
  const node = figma.createVector();
  node.name = name;
  node.vectorPaths = [{ windingRule: 'NONZERO', data }];
  node.resize(width, height);
  node.fills = fills;
  node.strokes = [];
  node.setPluginData('doglyadScreenShape', 'iphone17');
  return node;
}

function updateRetainedRegressionScreens(owner, staging) {
  // Only the plugin's managed regression section; unrelated page content stays untouched.
  const replacements = [];
  for (const section of owner.children.filter(node => node.getPluginData('doglyadSection') === 'regression'
      || node.name === 'Регресс')) {
    for (const group of section.children.filter(node => node.type === 'FRAME')) {
      for (const row of group.children.filter(node => node.layoutMode === 'HORIZONTAL')) {
        for (const card of row.children) {
          for (const image of [...(card.children || [])]) {
            if (image.type !== 'RECTANGLE' || !Array.isArray(image.fills)
                || !image.fills.some(fill => fill.type === 'IMAGE')) continue;
            const rounded = screenImage(image.name, image.width, image.height, image.fills);
            staging.appendChild(rounded);
            rounded.x = image.x;
            rounded.y = image.y;
            rounded.rotation = image.rotation;
            rounded.opacity = image.opacity;
            rounded.visible = image.visible;
            rounded.locked = image.locked;
            replacements.push({ card, image, rounded });
          }
        }
      }
    }
  }
  // Prepare every outline before replacing any existing screenshot.
  for (const { card, image, rounded } of replacements) {
    card.insertChild(card.children.indexOf(image), rounded);
    image.remove();
  }
}

function roundedImageCount(node) {
  return (node.getPluginData('doglyadScreenShape') === 'iphone17' ? 1 : 0)
    + (node.children || []).reduce((count, child) => count + roundedImageCount(child), 0);
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
    const section = frame(stage, kind === 'Preview' ? 'Макеты' : kind, 'VERTICAL', 40);
    section.setPluginData('doglyadSection', kind === 'Preview' ? 'previews' : 'regression');
    text(section, `${kind === 'Preview' ? 'Макеты' : kind} · ${images.length} снимков`
      + (value.scope === 'previews' ? ` · ${value.runId}` : ''), 40);
    const modules = [...new Set(images.map(image => imageGroup(image).module))];
    modules.sort((a, b) => {
      const rank = name => order.includes(name) ? order.indexOf(name) : order.length;
      return rank(a) - rank(b);
    });
    for (const module of modules) {
      const group = frame(section, kind === 'Preview' ? module : `${kind} / ${module}`, 'VERTICAL', 32);
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
        const card = frame(row, kind === 'Preview' ? title : `${kind} · ${module} · ${title}`, 'VERTICAL', 16);

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
  const section = ['Макеты', 'Preview', 'Регресс'].includes(collection.name)
    ? collection : collection.children[0];
  const firstModule = section && section.children && section.children[1];
  figma.viewport.scrollAndZoomIntoView([firstModule || section || collection]);
}

function previewOwner() {
  return target.children.find(node => node.getPluginData('complete') === '1'
    && (node.getPluginData('doglyadRegressionRun') || node.getPluginData('doglyadPreviewRun')));
}

function previewSection(owner) {
  return owner && owner.children.find(node => node.getPluginData('doglyadSection') === 'previews' || node.name === 'Preview');
}

function receipt(value, collection) {
  return { type: 'done', runId: value.runId, fileKey: figma.fileKey,
    nodeId: collection.id, imageCount: value.images.length,
    visibleImageCount: value.images.filter(visibleImage).length,
    scope: value.scope || 'regression', layoutVersion, screenShape: 'iphone17',
    roundedImageCount: roundedImageCount(value.scope === 'previews' ? collection.parent : collection) };
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
    if (value.scope === 'previews' && (value.expectedCases.some(id => !id.startsWith('atlas-'))
        || value.images.some(image => imageGroup(image).kind !== 'Preview'))) {
      throw new Error('A Preview refresh can contain only the complete Preview collection.');
    }
    if (!figma.fileKey || figma.fileKey !== value.figmaFileKey) {
      throw new Error('Open the Figma file configured in test/secrets/config.local.json.');
    }
    await figma.loadAllPagesAsync();
    target = figma.root.children.find(p => p.getPluginData('doglyadRegression') === '1')
      || figma.currentPage;
    previous = target.children.filter(n => n.getPluginData('doglyadRegressionRun') && n.getPluginData('complete') === '1');
    const existingPreview = previewSection(previewOwner());
    const existing = value.scope === 'previews'
      ? existingPreview && existingPreview.getPluginData('doglyadPreviewRun') === value.runId
        && existingPreview.getPluginData('suiteHash') === value.suiteHash
        && existingPreview.getPluginData('layoutVersion') === layoutVersion && existingPreview
      : previous.find(n => n.getPluginData('doglyadRegressionRun') === value.runId
      && n.getPluginData('suiteHash') === value.suiteHash
      && n.getPluginData('layoutVersion') === layoutVersion);
    if (existing) {
      await figma.setCurrentPageAsync(target);
      focusCollection(existing);
      figma.ui.postMessage(receipt(value, existing));
      return;
    }
    manifest = value;
    stage = frame(target, '', 'VERTICAL', 1920);
    stage.x = 0;
    stage.y = 0;
    const gaps = value.coverage && value.coverage.missingExecution
      ? value.coverage.missingExecution.length : 0;
    const runTitle = value.runId.replace(/^(\d{8}T\d{6}Z)-[0-9a-f]{8}$/, '$1');
    stage.name = `${value.scope === 'previews' ? 'Макеты' : value.figmaPageName || 'Doglyad Regression'} · ${runTitle}`
      + (gaps ? ` · ${gaps} сценариев требуют автоматизации` : '');
    stage.visible = false;
    stage.setPluginData(value.scope === 'previews' ? 'doglyadPreviewRun' : 'doglyadRegressionRun', value.runId);
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
    const screen = screenImage(row.name, 390, expected.height * 390 / expected.width,
      [{ type: 'IMAGE', scaleMode: 'FIT', imageHash: image.hash }]);
    row.appendChild(screen);
    received.add(message.id);
    figma.ui.postMessage({ type: 'received', id: message.id });
  } else if (message.type === 'commit') {
    if (!manifest || !stage || received.size !== manifest.images.length) throw new Error('Some images are missing.');
    await figma.setCurrentPageAsync(target);
    if (manifest.scope === 'previews') {
      const owner = previewOwner();
      const section = previewSection(stage);
      if (!section) throw new Error('Missing staged Preview section.');
      section.setPluginData('doglyadPreviewRun', manifest.runId);
      section.setPluginData('suiteHash', manifest.suiteHash);
      section.setPluginData('layoutVersion', layoutVersion);
      section.setPluginData('complete', '1');
      if (owner) {
        updateRetainedRegressionScreens(owner, stage);
        const old = previewSection(owner);
        owner.insertChild(old ? owner.children.indexOf(old) : 0, section);
        if (old) old.remove();
        owner.setPluginData('doglyadPreviewRun', manifest.runId);
        if (!owner.getPluginData('doglyadRegressionRun')) owner.name = stage.name;
        stage.remove();
      } else {
        stage.visible = true;
        stage.setPluginData('complete', '1');
      }
      focusCollection(owner || stage);
      const done = receipt(manifest, section);
      stage = null;
      manifest = null;
      target.setPluginData('doglyadRegression', '1');
      figma.ui.postMessage(done);
      return;
    }
    // The user dedicates this page to regression: remove every previous node,
    // including manual additions. Other pages are outside the publication target.
    for (const node of [...target.children]) if (node !== stage) node.remove();
    stage.visible = true;
    focusCollection(stage);
    stage.setPluginData('complete', '1');
    target.setPluginData('doglyadRegression', '1');
    const done = receipt(manifest, stage);
    stage = null;
    manifest = null;
    figma.ui.postMessage(done);
  } else if (message.type === 'abort') {
    rollback();
  }
}

figma.ui.onmessage = async message => {
  try { await handle(message); }
  catch (error) { rollback(); figma.ui.postMessage({ type: 'error', message: String(error.message || error) }); }
};
figma.on('close', rollback);
