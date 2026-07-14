# UI Design Compare Reference

Load this file only after deciding that a browser-rendered comparison is useful.

## Start the Companion

Run the server from this skill directory. In Copilot CLI, use an asynchronous
Bash session because `--foreground` keeps the server alive across turns:

```bash
scripts/start-server.sh --open --foreground
```

The first output line is JSON:

```json
{
  "type": "server-started",
  "url": "http://localhost:54321/?key=...",
  "session_dir": "/tmp/ui-design-compare-...",
  "screen_dir": "/tmp/ui-design-compare-.../content",
  "state_dir": "/tmp/ui-design-compare-.../state"
}
```

Keep the complete URL, including `?key=...`. Write each screen as a new `.html`
file in `screen_dir`. Use semantic names such as `navigation-options.html` and
`navigation-options-v2.html`.

For a remote machine, start with an explicit bind and browser-visible host only
when loopback forwarding is unavailable:

```bash
scripts/start-server.sh \
  --host 0.0.0.0 \
  --url-host 10.0.0.4 \
  --foreground
```

The keyed URL is an access credential for the temporary server. Do not publish
or commit it.

## Authoring Screens

Write HTML fragments by default. The server supplies the document shell,
responsive CSS, click handling, live reload, and selection styling.

### Side-by-side mockups

```html
<header class="screen-intro">
  <p class="eyebrow">Dashboard navigation</p>
  <h1>Which information model feels clearer?</h1>
  <p>Compare scan speed, hierarchy, and room for future sections.</p>
</header>

<div class="compare-grid">
  <article class="option-card" data-choice="rail" onclick="toggleSelect(this)"
           role="button" tabindex="0">
    <div class="option-heading">
      <span class="choice">A</span>
      <div>
        <h2>Persistent Rail</h2>
        <p>Fast switching for a dense daily-use product.</p>
      </div>
    </div>
    <div class="preview">
      <!-- Render the first mockup here. -->
    </div>
  </article>

  <article class="option-card" data-choice="topbar" onclick="toggleSelect(this)"
           role="button" tabindex="0">
    <div class="option-heading">
      <span class="choice">B</span>
      <div>
        <h2>Focused Top Bar</h2>
        <p>More canvas space with a simpler information model.</p>
      </div>
    </div>
    <div class="preview">
      <!-- Render the second mockup here. -->
    </div>
  </article>
</div>
```

### Browser and phone frames

```html
<div class="browser-frame">
  <div class="browser-chrome"><span></span><span></span><span></span></div>
  <div class="browser-body">Desktop mockup</div>
</div>

<div class="phone-frame">
  <div class="phone-island"></div>
  <div class="phone-body">Mobile mockup</div>
</div>
```

### Supporting components

Available classes include:

- `compare-grid`, `option-card`, `option-heading`, `choice`, `preview`
- `browser-frame`, `browser-chrome`, `browser-body`
- `phone-frame`, `phone-island`, `phone-body`
- `mock-nav`, `mock-sidebar`, `mock-content`, `mock-button`, `mock-input`
- `swatches`, `swatch`, `tag`, `callout`, `pros-cons`, `split`

Custom CSS may be included in the fragment when the comparison needs a distinct
visual language. Scope it under a screen-specific wrapper to avoid collisions.

## Read Feedback

Clicks are appended to `state_dir/events` as JSON Lines:

```json
{"type":"click","choice":"rail","text":"A Persistent Rail","timestamp":1784010000000}
```

The terminal response remains authoritative. Click history is supporting
evidence and may show hesitation or comparison order.

## Iterate and Stop

Push revisions using new filenames. The open browser reloads automatically when
a newer screen appears.

Stop the server with:

```bash
scripts/stop-server.sh "$session_dir"
```

Temporary sessions remain under `/tmp` for normal operating-system cleanup.
