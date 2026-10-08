// The study cell: a client from the notebook, and one of its studies.
export function init(ctx, payload) {
  ctx.importCSS("main.css");

  ctx.root.innerHTML = `
    <div class="castor-cell">
      <div class="castor-header">Castor EDC study</div>
      <div class="castor-row">
        <label class="castor-field">
          <span>Assign to</span>
          <input type="text" name="variable" />
        </label>
        <label class="castor-field">
          <span>Client</span>
          <select name="client"></select>
        </label>
        <label class="castor-field castor-grow">
          <span>Study</span>
          <select name="study_id"></select>
        </label>
        <div class="castor-field">
          <button type="button" class="castor-button" name="refresh" title="List the studies again">Refresh</button>
        </div>
      </div>
      <div class="castor-message" hidden></div>
    </div>
  `;

  const root = ctx.root;
  let state = payload;

  function options(select, items, selected, empty) {
    select.innerHTML = "";
    if (items.length === 0) {
      const option = document.createElement("option");
      option.value = "";
      option.textContent = empty;
      select.appendChild(option);
    }
    items.forEach((item) => {
      const option = document.createElement("option");
      option.value = item.value;
      option.textContent = item.label;
      select.appendChild(option);
    });
    select.value = selected;
  }

  function render() {
    const fields = state.fields;
    const variable = root.querySelector('input[name="variable"]');
    if (document.activeElement !== variable) variable.value = fields.variable;

    options(
      root.querySelector('select[name="client"]'),
      state.clients.map((name) => ({ value: name, label: name })),
      fields.client,
      "No client in the notebook yet"
    );

    let studies = state.studies.map((study) => ({ value: study.id, label: study.name || study.id }));
    if (fields.study_id && !studies.some((study) => study.value === fields.study_id)) {
      studies = [{ value: fields.study_id, label: fields.study_name || fields.study_id }, ...studies];
    }
    if (studies.length > 0 && !fields.study_id) {
      studies = [{ value: "", label: "Choose a study" }, ...studies];
    }
    options(root.querySelector('select[name="study_id"]'), studies, fields.study_id, "No studies");

    const message = root.querySelector(".castor-message");
    message.hidden = !state.status;
    message.textContent = state.status || "";
  }

  root.querySelectorAll("input[name], select[name]").forEach((input) => {
    input.addEventListener("change", (event) => {
      ctx.pushEvent("update_field", { field: input.name, value: event.target.value });
    });
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
