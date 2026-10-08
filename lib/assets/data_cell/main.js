// The study data cell: which client and study, which library, and how.
export function init(ctx, payload) {
  ctx.importCSS("main.css");

  ctx.root.innerHTML = `
    <div class="castor-cell">
      <div class="castor-header">Castor EDC study data</div>
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
          <span>Load as</span>
          <select name="library"></select>
        </label>
      </div>
      <div class="castor-row">
        <label class="castor-field" data-frames>
          <span>From</span>
          <select name="source">
            <option value="api">Data points (API)</option>
            <option value="export">Participant data export</option>
          </select>
        </label>
        <label class="castor-field" data-api data-frames>
          <span>Shape</span>
          <select name="format">
            <option value="long">A row per value</option>
            <option value="wide">A column per variable</option>
          </select>
        </label>
        <div class="castor-field" data-api>
          <span>Sources</span>
          <div class="castor-checks">
            <label><input type="checkbox" value="study" /> Study</label>
            <label><input type="checkbox" value="repeating_data" /> Repeating data</label>
            <label><input type="checkbox" value="survey" /> Surveys</label>
          </div>
        </div>
        <div class="castor-field" data-missing>
          <span>Missing values</span>
          <div class="castor-checks">
            <label><input type="checkbox" name="missing_columns" /> Add their codes as columns</label>
          </div>
        </div>
      </div>
    </div>
  `;

  const root = ctx.root;
  let state = payload;

  function options(select, items, selected, empty) {
    select.innerHTML = "";
    const values = items.map((item) => item.value);
    if (selected && !values.includes(selected)) items = [{ value: selected, label: selected }, ...items];
    if (items.length === 0) items = [{ value: "", label: empty }];
    items.forEach((item) => {
      const option = document.createElement("option");
      option.value = item.value;
      option.textContent = item.label;
      select.appendChild(option);
    });
    select.value = selected;
  }

  function render() {
    const f = state.fields;
    const variable = root.querySelector('input[name="variable"]');
    if (document.activeElement !== variable) variable.value = f.variable;

    options(root.querySelector('select[name="client"]'), state.clients.map((c) => ({ value: c, label: c })), f.client, "No client yet");
    options(root.querySelector('select[name="study"]'), state.studies.map((s) => ({ value: s, label: s })), f.study, "No study ID yet");
    options(root.querySelector('select[name="library"]'), state.libraries, f.library, "Rows");
    root.querySelector('select[name="source"]').value = f.source;
    root.querySelector('select[name="format"]').value = f.format;

    root.querySelectorAll(".castor-checks input[value]").forEach((box) => (box.checked = f.sources.includes(box.value)));
    root.querySelector('input[name="missing_columns"]').checked = f.missing_columns;

    const frames = f.library !== "rows";
    const api = f.library === "rows" || f.source === "api";
    root.querySelectorAll("[data-frames]").forEach((el) => (el.hidden = !frames));
    root.querySelectorAll("[data-api]").forEach((el) => (el.hidden = !api || (el.hasAttribute("data-frames") && !frames)));
    root.querySelector("[data-missing]").hidden = !frames || (f.source === "api" && f.format !== "wide");
  }

  const push = (field, value) => ctx.pushEvent("update_field", { field, value });

  root.querySelectorAll("input[name=variable], select[name]").forEach((input) => {
    input.addEventListener("change", (event) => push(input.name, event.target.value));
  });

  root.querySelectorAll(".castor-checks input[value]").forEach((box) => {
    box.addEventListener("change", () => {
      const sources = [...root.querySelectorAll(".castor-checks input[value]:checked")].map((b) => b.value);
      if (sources.length === 0) return render();
      push("sources", sources);
    });
  });

  root.querySelector('input[name="missing_columns"]').addEventListener("change", (event) => push("missing_columns", event.target.checked));

  ctx.handleEvent("update", (payload) => {
    state = payload;
    render();
  });

  ctx.handleSync(() => {
    document.activeElement && document.activeElement.dispatchEvent(new Event("change"));
  });

  render();
}
