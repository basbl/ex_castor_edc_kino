// The connection cell: a server, and credentials or an access token from
// Livebook secrets. Every change goes to the server, which owns the fields.
export function init(ctx, payload) {
  ctx.importCSS("main.css");

  let fields = payload.fields;

  ctx.root.innerHTML = `
    <div class="castor-cell">
      <div class="castor-header">Castor EDC connection</div>
      <div class="castor-row">
        <label class="castor-field">
          <span>Assign to</span>
          <input type="text" name="variable" />
        </label>
        <label class="castor-field castor-grow">
          <span>Server</span>
          <select name="server"></select>
        </label>
        <label class="castor-field castor-grow" data-show="custom">
          <span>URL</span>
          <input type="url" name="custom_server" placeholder="https://..." />
        </label>
      </div>
      <div class="castor-row">
        <label class="castor-field">
          <span>Authentication</span>
          <select name="auth">
            <option value="credentials">Client ID and secret</option>
            <option value="token">Access token</option>
          </select>
        </label>
        <div class="castor-field" data-auth="credentials">
          <span>Client ID</span>
          <button type="button" class="castor-secret" data-secret="client_id_secret"></button>
        </div>
        <div class="castor-field" data-auth="credentials">
          <span>Client secret</span>
          <button type="button" class="castor-secret" data-secret="client_secret_secret"></button>
        </div>
        <div class="castor-field" data-auth="token">
          <span>Access token</span>
          <button type="button" class="castor-secret" data-secret="access_token_secret"></button>
        </div>
        <div class="castor-field castor-end">
          <button type="button" class="castor-button" name="test">Test connection</button>
        </div>
      </div>
      <div class="castor-hint">Each value comes from the Livebook secret named on its button; click it to choose another.</div>
      <div class="castor-message castor-error" data-warning hidden></div>
      <div class="castor-message" data-test hidden></div>
    </div>
  `;

  const root = ctx.root;
  const select = root.querySelector('select[name="server"]');
  payload.servers.forEach((server) => {
    const option = document.createElement("option");
    option.value = server.value;
    option.textContent = server.label;
    select.appendChild(option);
  });

  function render() {
    root.querySelectorAll("input[name], select[name]").forEach((input) => {
      if (document.activeElement !== input) input.value = fields[input.name];
    });
    root.querySelectorAll("[data-secret]").forEach((button) => {
      button.textContent = fields[button.dataset.secret];
      button.title = `Uses the Livebook secret ${fields[button.dataset.secret]}`;
    });
    root.querySelectorAll("[data-show]").forEach((element) => {
      element.hidden = fields.server !== element.dataset.show;
    });
    root.querySelectorAll("[data-auth]").forEach((element) => {
      element.hidden = fields.auth !== element.dataset.auth;
    });
  }

  function showWarning(warning) {
    const message = root.querySelector("[data-warning]");
    message.hidden = !warning;
    message.textContent = warning || "";
  }

  function showTest(test) {
    const message = root.querySelector("[data-test]");
    message.hidden = !test;
    if (test) {
      message.textContent = test.message;
      message.classList.toggle("castor-error", !test.ok);
    }
  }

  root.querySelectorAll("input[name], select[name]").forEach((input) => {
    input.addEventListener("change", (event) => {
      ctx.pushEvent("update_field", { field: input.name, value: event.target.value });
    });
  });

  root.querySelectorAll("[data-secret]").forEach((button) => {
    button.addEventListener("click", () => {
      ctx.selectSecret((name) => {
        ctx.pushEvent("update_field", { field: button.dataset.secret, value: name });
      }, fields[button.dataset.secret]);
    });
  });

  root.querySelector('button[name="test"]').addEventListener("click", () => {
    showTest({ ok: true, message: "Connecting…" });
    ctx.pushEvent("test", {});
  });

  ctx.handleEvent("update", (payload) => {
    fields = payload.fields;
    render();
    showWarning(payload.warning);
    showTest(null);
  });

  ctx.handleEvent("test", showTest);

  ctx.handleSync(() => {
    document.activeElement && document.activeElement.dispatchEvent(new Event("change"));
  });

  render();
  showWarning(payload.warning);
  showTest(payload.test);
}
