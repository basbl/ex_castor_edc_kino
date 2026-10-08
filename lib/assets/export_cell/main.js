// The export download cell: a study's existing exports, and where to put
// the one picked. It never queues an export.
export function init(ctx, payload) {
  ctx.importCSS("main.css");

  ctx.root.innerHTML = `
    <div class="castor-cell">
      <div class="castor-header">Castor EDC export download</div>
      <div class="castor-row">
        <label class="castor-field">
          <span>Assign to</span>
          <input type="text" name="variable" />
        </label>
        <label class="castor-field">
          <span>Client</span>
          <select name="client"></select>
        </label>
        <label class="castor-field">
          <span>Study</span>
          <select name="study"></select>
        </label>
        <label class="castor-field castor-grow">
          <span>Save in</span>
          <input type="text" name="into" placeholder="Memory (or a directory, such as exports/)" />
        </label>
      </div>
      <div class="castor-row">
        <label class="castor-field castor-grow">
          <span>Export</span>
          <select name="export_id"></select>
        </label>
        <div class="castor-field">
          <button type="button" class="castor-button" name="refresh" title="List the exports again">Refresh</button>
        </div>
      </div>
      <div class="castor-hint">Lists the exports that already exist; queue new ones with CastorEDC.Export.</div>
      <div class="castor-message" hidden></div>
    </div>
  `;

  const root = ctx.root;
  let state = payload;

  function options(select, items, selected, empty) {
    select.innerHTML = "";
    if (selected && !items.some((item) => item.value === selected)) items = [{ value: selected, label: selected }, ...items];
    if (items.length === 0) items = [{ value: "", label: empty }];
    items.forEach((item) => {
      const option = document.createElement("option");
      option.value = item.value;
      option.textContent = item.label;
      option.disabled = item.disabled || false;
      select.appendChild(option);
    });
    select.value = selected;
  }

  function render() {
    const f = state.fields;
    root.querySelectorAll("input[name]").forEach((input) => {
      if (document.activeElement !== input) input.value = f[input.name];
    });
    options(root.querySelector('select[name="client"]'), state.clients.map((c) => ({ value: c, label: c })), f.client, "No client yet");
    options(root.querySelector('select[name="study"]'), state.studies.map((s) => ({ value: s, label: s })), f.study, "No study ID yet");

    let exports = state.exports.map((e) => ({ value: e.id, label: e.label, disabled: !e.ready }));
    if (f.export_id && !exports.some((e) => e.value === f.export_id)) exports = [{ value: f.export_id, label: f.export_label || f.export_id }, ...exports];
    if (!f.export_id && exports.length > 0) exports = [{ value: "", label: "Choose an export" }, ...exports];
    options(root.querySelector('select[name="export_id"]'), exports, f.export_id, "No exports");

    const message = root.querySelector(".castor-message");
    message.hidden = !state.status;
    message.textContent = state.status || "";
  }

  root.querySelectorAll("input[name], select[name]").forEach((input) => {
    input.addEventListener("change", (event) => ctx.pushEvent("update_field", { field: input.name, value: event.target.value }));
  });

  root.querySelector('button[name="refresh"]').addEventListener("click", () => ctx.pushEvent("refresh", {}));

  ctx.handleEvent("update", (payload) => {
    state = payload;
    render();
  });

  ctx.handleSync(() => {
    document.activeElement && document.activeElement.dispatchEvent(new Event("change"));
  });

  render();
}
