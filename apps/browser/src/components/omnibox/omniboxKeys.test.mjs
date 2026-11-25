import assert from "node:assert/strict";
import { test } from "node:test";
globalThis.require ??= (id) => ({ asset: id });
const { barKeyDown, barKeyDownEvents } = await import("./omniboxKeys.ts");

const items = [{ url: "https://a.example/" }, { url: "https://b.example/" }, { url: "https://c.example/" }];

const context = (selectedIndex) => {
  const dispatched = [];
  return {
    dispatched,
    bar: { scope: null, typed: "", scopeFrom: "", dispatch: (action) => dispatched.push(action) },
    hero: false, shownCompletion: "", input: "", items, selectedIndex, previewing: false, current: items[selectedIndex], tabScope: null,
    cancelBang: () => {}, reset: () => {}, removeRow: () => {}, rowsHeld: false, releaseRows: () => {}, forceSearch: () => {}, go: () => {}, choose: () => {},
  };
};

const press = (key, extra = {}) => ({ nativeEvent: { key, ...extra } });

test("Ctrl+J and Ctrl+N move to the next row, Ctrl+K and Ctrl+P to the previous, both wrapping", () => {
  for (const key of ["j", "n"]) {
    const atTop = context(0);
    barKeyDown(press(key, { ctrlKey: true }), atTop);
    assert.deepEqual(atTop.dispatched, [{ kind: "selected", index: 1 }], `Ctrl+${key} moves down`);
    const atBottom = context(2);
    barKeyDown(press(key, { ctrlKey: true }), atBottom);
    assert.deepEqual(atBottom.dispatched, [{ kind: "selected", index: 0 }], `Ctrl+${key} wraps from the last row`);
  }
  for (const key of ["k", "p"]) {
    const atTop = context(0);
    barKeyDown(press(key, { ctrlKey: true }), atTop);
    assert.deepEqual(atTop.dispatched, [{ kind: "selected", index: 2 }], `Ctrl+${key} wraps from the first row`);
    const atBottom = context(2);
    barKeyDown(press(key, { ctrlKey: true }), atBottom);
    assert.deepEqual(atBottom.dispatched, [{ kind: "selected", index: 1 }], `Ctrl+${key} moves up`);
  }
  const typing = context(0);
  for (const key of ["j", "k"]) barKeyDown(press(key), typing);
  assert.deepEqual(typing.dispatched, [], "j and k without Ctrl stay typed text");
});

test("the field delivers Ctrl+J/K to the bar in every row state, as it already does Ctrl+N/P", () => {
  for (const [scope, removable] of [[false, false], [true, false], [false, true]]) {
    const events = barKeyDownEvents(scope, removable);
    for (const key of ["j", "k", "n", "p"]) {
      assert.ok(events.some((event) => event.key === key && event.ctrlKey === true), `${key} with Ctrl is delivered when scope=${scope} removable=${removable}`);
    }
  }
});
