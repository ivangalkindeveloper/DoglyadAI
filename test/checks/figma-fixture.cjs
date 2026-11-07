const fs = require('node:fs');
const vm = require('node:vm');

function environment({ managed = true, pageLimit = false } = {}) {
  let serial = 0;
  function node() {
    return { id: String(++serial), children: [], removed: false, data: {}, x: 0, y: 0,
      getPluginData(key) { return this.data[key] || ''; },
      setPluginData(key, value) { this.data[key] = value; },
      appendChild(child) {
        if (child.parent) child.parent.children = child.parent.children.filter(n => n !== child);
        this.children.push(child); child.parent = this;
      },
      resize() {}, remove() {
        this.removed = true;
        if (this.parent) this.parent.children = this.parent.children.filter(n => n !== this);
      }
    };
  }
  const page = node(); page.name = 'User designs';
  if (managed) page.setPluginData('doglyadRegression', '1');
  const old = node(); old.setPluginData('doglyadRegressionRun', 'old'); old.setPluginData('complete', '1');
  old.x = 1200; old.y = 80;
  const manual = node();
  manual.absoluteBoundingBox = { x: 100, y: -40, width: 800, height: 600 };
  if (managed) page.appendChild(old);
  page.appendChild(manual);
  const messages = [];
  const pages = pageLimit ? [node(), page, node()] : [page];
  const figma = { fileKey: 'file', root: { children: pages }, currentPage: page, showUI() {},
    ui: { postMessage: value => messages.push(value) }, loadAllPagesAsync: async () => {},
    loadFontAsync: async () => {}, setCurrentPageAsync: async () => {},
    createPage() { throw new Error('The Starter plan only comes with 3 pages.'); },
    createFrame: node, createText: node, createRectangle: node,
    createImage: () => ({ hash: 'image' }), on() {}, viewport: { scrollAndZoomIntoView() {} } };
  vm.runInNewContext(fs.readFileSync('test/figma/code.js', 'utf8'), { figma, __html__: '', Uint8Array });
  const manifest = { runId: 'new', suiteHash: 'suite', status: 'passed', expectedScreenshots: 2,
    expectedCases: ['case'], results: [{ id: 'case', exitCode: 0 }], figmaFileKey: 'file', figmaPageName: 'Regression',
    images: ['one', 'two'].map(id => ({ id, screen: 'screen', state: id, width: 390, height: 844 })) };
  return { figma, page, old, manual, messages, manifest };
}

module.exports = { environment };
