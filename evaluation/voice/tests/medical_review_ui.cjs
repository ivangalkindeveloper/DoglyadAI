// Test the offline UI data flow with a small DOM; this is not a browser render test.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const html = fs.readFileSync(process.argv[2], "utf8");
const embedded = html.match(/<script id="review-data" type="application\/json">([\s\S]*?)<\/script>/)[1];
const script = html.match(/<script>\s*([\s\S]*?)<\/script>/)[1];

function openPage(storage = new Map(), options = {}) {
  const nodes = [];
  class Element {
    constructor(tag) { this.tag = tag; this.dataset = {}; this.events = {}; this.children = []; this.value = ""; nodes.push(this); }
    append(child) { this.children.push(child); }
    addEventListener(name, callback) { this.events[name] = callback; }
    setAttribute(name, value) { this[name] = value; }
    click() { this.events.click?.(); }
    remove() {}
  }
  const ids = Object.fromEntries(["review-data", "status", "items", "counts", "filter", "reviewer", "date", "save", "download", "restore", "upload", "choose-packet", "review-workspace"].map(id => [id, new Element("div")]));
  ids["review-data"].textContent = options.embedded || embedded;
  ids["choose-packet"].hidden = false; ids["review-workspace"].hidden = true;
  const events = {};
  const page = {ids, nodes, events, downloaded:null};
  const context = vm.createContext({
    document: {getElementById:id => ids[id], createElement:tag => new Element(tag), body:new Element("body"), querySelectorAll:query => nodes.filter(node => query === ".case" ? node.className === "case" : node.dataset.item)},
    window: {
      addEventListener:(name, callback) => { events[name] = callback; }, confirm:() => true,
      localStorage: {
        getItem:key => { if(options.isReadFailure) throw new Error("storage blocked"); return storage.get(key) ?? null; },
        setItem:(key, value) => { if(options.isWriteFailure) throw new Error("quota exceeded"); storage.set(key,value); },
      },
    },
    URL: {createObjectURL:blob => { page.downloaded = blob; return "blob:test"; }, revokeObjectURL() {}},
    Blob, setTimeout:callback => callback(),
  });
  vm.runInContext(script, context);
  page.openFirst = () => { const box = nodes.find(node => node.className === "case"); box.open = true; box.events.toggle(); return nodes.find(node => node.dataset.key === "heardText"); };
  page.isUnloadBlocked = () => { let isPrevented = false; events.beforeunload({preventDefault() { isPrevented = true; }}); return isPrevented; };
  return page;
}

(async () => {
  if(process.argv[3] === "launcher") {
    const page = openPage();
    assert.equal(page.ids["choose-packet"].hidden, false);
    assert.equal(page.ids["review-workspace"].hidden, true);
    assert.equal(page.nodes.some(node => node.className === "case"), false);
    console.log("direct template opening shows packet selection without a script error");
    return;
  }
  const storage = new Map();
  const page = openPage(storage);
  assert.equal(page.ids["choose-packet"].hidden, true);
  assert.equal(page.ids["review-workspace"].hidden, false);
  const heard = page.openFirst();
  heard.value = "TEST ONLY: transcript review"; heard.events.input();
  page.ids.reviewer.value = "test-reviewer"; page.ids.date.value = "2026-10-25";
  assert.equal(page.isUnloadBlocked(), true);
  page.ids.save.click();
  assert.equal(storage.size,1);
  assert.equal(page.isUnloadBlocked(), false);
  const firstSaved = [...storage.values()][0];

  // A new page instance automatically restores answers, identity and date.
  const resumed = openPage(storage);
  assert.equal(resumed.ids.reviewer.value,"test-reviewer");
  assert.equal(resumed.ids.date.value,"2026-10-25");
  const restored = resumed.openFirst();
  assert.equal(restored.value, heard.value);
  restored.value = "Updated test answer"; restored.events.input();
  resumed.nodes.find(node => node.tag === "button" && node.textContent === "Сохранить тесткейс").click();
  assert.equal(openPage(storage).openFirst().value,"Updated test answer");

  // Export/import round trip and rejection of a different dataset.
  resumed.ids.download.click();
  const draft = JSON.parse(await resumed.downloaded.text());
  assert.equal(draft.isClinicallyValidated, false);
  const imported = openPage(new Map()); const importedField = imported.openFirst();
  await imported.ids.upload.events.change({target:{files:[{text:async () => JSON.stringify(draft)}]}});
  assert.equal(importedField.value,"Updated test answer");
  assert.equal(imported.isUnloadBlocked(),true);
  imported.ids.save.click(); assert.equal(imported.isUnloadBlocked(),false);
  await imported.ids.upload.events.change({target:{files:[{text:async () => JSON.stringify({...draft, manifestSha256:"different"})}]}});
  assert.match(imported.ids.status.textContent,/Не удалось/);
  assert.equal(importedField.value,"Updated test answer");

  // Failed writes retain the previous snapshot and leave current edits unsaved.
  const prior = new Map(storage); const broken = openPage(storage,{isWriteFailure:true});
  const pending = broken.openFirst(); pending.value = "Not saved"; pending.events.input(); broken.ids.save.click();
  assert.deepEqual(storage,prior); assert.equal(pending.value,"Not saved"); assert.equal(broken.isUnloadBlocked(),true);
  assert.match(broken.ids.status.textContent,/Не удалось сохранить/);
  const denied = openPage(new Map(),{isReadFailure:true});
  denied.ids.save.click(); assert.match(denied.ids.status.textContent,/недоступно/);

  // Never silently overwrite a newer snapshot from another tab or corrupt data.
  page.ids.save.click(); assert.match(page.ids.status.textContent,/другой вкладке/); assert.deepEqual(storage,prior);
  const key = [...storage.keys()][0]; const corruptStorage = new Map([[key,"broken JSON"]]);
  const corrupt = openPage(corruptStorage); corrupt.ids.save.click(); assert.equal(corruptStorage.get(key),"broken JSON");
  const otherData = JSON.parse(embedded); otherData.manifest.manifestSha256 = "another corpus";
  assert.equal(openPage(storage,{embedded:JSON.stringify(otherData)}).openFirst().value,"");
  assert.notEqual([...storage.values()][0],firstSaved);
  page.ids.filter.events.input({target:{value:"no-such-examination"}});
  assert.equal(page.nodes.find(node => node.className === "case").hidden,true);
  console.log("save/reopen, per-testcase save, export/import, storage failures, conflicts and dataset isolation passed");
})().catch(error => { console.error(error); process.exitCode = 1; });
