const icon = name => `<svg class="icon" aria-hidden="true"><use href="#${name}"/></svg>`;
const applications = [
  { name: 'Terminal', description: 'A quiet place to get things done', icon: 'terminal', keywords: 'shell command console' },
  { name: 'Firefox', description: 'Web browser', icon: 'browser', keywords: 'internet web' },
  { name: 'Files', description: 'Your files and folders', icon: 'folder', keywords: 'directory explorer' },
  { name: 'Code Editor', description: 'Projects, configuration, and code', icon: 'code', keywords: 'development text' },
  { name: 'Appearance', description: 'Make the desktop yours', icon: 'gear', keywords: 'theme settings' },
];
const concepts = {
  citadel: {
    number: '01', title: 'Citadel', panelTitle: 'System controls', character: 'Architectural / deliberate / focused',
    presence: 'An edge-integrated bar. Crisp divisions, measured spacing, and a workspace indicator with a clear sense of place.',
    workflow: 'Search is the center of gravity. System controls are a compact instrument panel, not a dashboard competing with your work.',
    tradeoff: 'More disciplined than playful. Strong hierarchy has to come from type and composition, not rounded cards everywhere.',
  },
  orbit: {
    number: '02', title: 'Orbit', panelTitle: 'Your space', character: 'Expressive / grounded / personal',
    presence: 'A continuous edge bar anchors the desktop. Soft workspace indicators and sculptural wallpaper retain Orbit\'s character without floating top chrome.',
    workflow: 'Quick Controls handles everyday actions. A separate Settings window gives appearance and deeper preferences room to grow.',
    tradeoff: 'A direction to refine, not a final choice. The softer panels and proposed app shelf remain; typography, density, and layout are still open for feedback.',
  },
};

// The same fixtures and controls make layout, not feature count, the comparison.
document.querySelector('#desktops').innerHTML = Object.keys(concepts).map(concept => `
  <article class="desktop-study" data-concept="${concept}" data-palette="catppuccin-mocha" data-surface="overview" aria-label="${concepts[concept].title} desktop concept" ${concept === 'citadel' ? 'hidden' : ''}>
    <div class="wallpaper" aria-hidden="true">
      <svg class="citadel-art" viewBox="0 0 1400 680" preserveAspectRatio="xMidYMid slice">
        <path d="M0 680V520L560 260l600 250v170Z" fill="var(--surface)"/>
        <path d="m420 680 480-470 500 390v80Z" fill="var(--elevated)" opacity=".4"/>
        <path d="m570 680 330-470 155 121-204 349Z" fill="var(--accent)" opacity=".09"/>
        <path d="M570 680 900 210l500 390M0 520l560-260 600 250" fill="none" stroke="var(--subtle)" stroke-width="1" opacity=".3"/>
        <path d="m708 480 180 3m-213 45 181 3m-217 49 184 3m-220 53 187 3" fill="none" stroke="var(--accent)" opacity=".15"/>
        <circle cx="1030" cy="153" r="64" fill="none" stroke="var(--accent)" opacity=".18"/>
        <path d="M966 153h128m-64-64v128" stroke="var(--accent)" opacity=".14"/>
      </svg>
      <svg class="orbit-art" viewBox="0 0 1400 680" preserveAspectRatio="xMidYMid slice">
        <circle cx="1070" cy="215" r="320" fill="var(--accent)" opacity=".1"/>
        <circle cx="1070" cy="215" r="236" fill="var(--accent)" opacity=".09"/>
        <circle cx="1070" cy="215" r="160" fill="var(--accent)" opacity=".08"/>
        <circle cx="1070" cy="215" r="84" fill="var(--warning)" opacity=".16"/>
        <path d="M-100 600C180 210 370 210 640 485S1050 720 1480 360v420H-100Z" fill="var(--surface)"/>
        <path d="M-100 640C180 285 370 285 640 535S1050 750 1480 410" fill="none" stroke="var(--accent)" stroke-width="45" opacity=".1"/>
        <path d="M-100 670C180 350 370 350 640 580S1050 780 1480 460" fill="none" stroke="var(--accent)" stroke-width="20" opacity=".08"/>
        <path d="M-100 700C180 420 370 420 640 625S1050 810 1480 510" fill="none" stroke="var(--accent)" stroke-width="8" opacity=".12"/>
      </svg>
      <div class="wallpaper-grid"></div>
      <div class="wallpaper-coordinate">NIXOS / ${concepts[concept].number}<span>SENNTISTEN &middot; PERSONAL DESKTOP</span></div>
    </div>
    <div class="desktop-bar" aria-label="Simulated desktop bar">
      <div class="bar-left">
        <button class="bar-button brand-action" type="button" data-toggle="launcher" aria-controls="launcher-${concept}" aria-expanded="true" aria-label="Toggle preview launcher" title="NixOS / Application launcher (preview)">${icon('distro-nixos')}</button>
        <div class="workspace-list" role="group" aria-label="Preview workspaces">${[1, 2, 3, 4].map(number => `<button type="button" data-workspace="${number}" aria-label="Preview workspace ${number}" aria-pressed="${number === 2}">${number}</button>`).join('')}</div>
        <span class="window-context">${icon('code')}senntisten-shell</span>
      </div>
      <span class="bar-clock">09:41<span>Mon, 05 Oct</span></span>
      <div class="bar-right"><span class="bar-tray" aria-hidden="true">${icon('terminal')}${icon('bell')}</span><button class="bar-button status-action" type="button" data-toggle="controls" aria-controls="controls-${concept}" aria-expanded="true" aria-label="Toggle preview controls">${icon('wifi')}${icon('speaker')}<span class="status-label">42%</span>${icon('battery')}</button><button class="bar-button" type="button" data-open="settings" aria-controls="settings-${concept}" aria-expanded="false" aria-label="Preview settings">${icon('gear')}</button></div>
    </div>
    <div class="mock-window" aria-hidden="true">
      <div class="mock-title"><span>desktop.nix &mdash; senntisten-shell</span><span class="window-dots">&middot;&middot;&middot;</span></div>
      <div class="mock-editor"><div class="mock-files"><strong>Explorer</strong>shell/<br>&nbsp; desktop/<br>&nbsp;&nbsp; Bar.qml<br>&nbsp;&nbsp; Launcher.qml<br>&nbsp; services/<br>&nbsp;&nbsp; Theme.qml</div><pre class="mock-code"><em>{</em> config, pkgs, ... <em>}:</em>

<em>{</em>
  programs.hyprland.enable = <b>true</b>;

  <span># A desktop that feels like home.</span>
  environment.systemPackages = <em>[</em>
    pkgs.quickshell
  <em>];</em>
<em>}</em></pre></div>
      <div class="mock-status">main &nbsp; / &nbsp; Nix &nbsp; / &nbsp; UTF-8 &nbsp; / &nbsp; design fixture</div>
    </div>
    <div class="panels">
      <section class="panel launcher" id="launcher-${concept}" aria-label="Preview application launcher">
        <div class="panel-caption"><p class="eyebrow">Applications</p><button class="close-button" type="button" data-close="launcher" aria-label="Close preview launcher">${icon('close')}</button></div>
        <div class="search-field">${icon('search')}<input type="search" aria-label="Search preview applications" placeholder="Find an application" autocomplete="off" spellcheck="false" aria-controls="results-${concept}" aria-activedescendant="app-${concept}-0"></div>
        <div class="result-caption"><span>Preview applications</span><span class="result-count">05 results</span></div>
        <div class="results" id="results-${concept}" role="listbox" aria-label="Preview application results">${applications.map((app, index) => `<div class="app-result" id="app-${concept}-${index}" role="option" aria-selected="${index === 0}" data-app="${app.name}" data-keywords="${app.keywords}" tabindex="-1"><span class="app-icon">${icon(app.icon)}</span><span class="app-copy"><strong>${app.name}</strong><small>${app.description}</small></span><svg class="icon result-action" aria-hidden="true"><use href="#arrow"/></svg></div>`).join('')}<p class="empty-results" hidden>No matching preview applications.</p></div>
        <div class="launcher-footer"><span><kbd>&uarr;</kbd><kbd>&darr;</kbd> navigate <kbd>Enter</kbd> select</span><span class="fixture-tag">Preview only</span></div>
      </section>
      <section class="panel control-panel" id="controls-${concept}" aria-label="Preview system controls">
        <div class="panel-caption"><p class="eyebrow">Your desktop</p><button class="close-button" type="button" data-close="controls" aria-label="Close preview controls">${icon('close')}</button></div>
        <div class="control-heading"><div><h3>${concepts[concept].panelTitle}</h3><p>Monday, October 5 &middot; example session</p></div><span class="profile-mark" aria-hidden="true">F</span></div>
        <div class="status-tiles"><div class="status-tile">${icon('wifi')}<span class="planned-tag">Planned</span><strong>Home network</strong><small>Wi-Fi &middot; example data</small></div><div class="status-tile">${icon('bluetooth')}<span class="planned-tag">Planned</span><strong>Headphones</strong><small>Bluetooth &middot; example data</small></div></div>
        <div class="audio-control"><div class="control-label"><span>${icon('speaker')}Output volume</span><output>42%</output></div><input type="range" min="0" max="100" value="42" aria-label="Preview output volume"><p class="service-warning" hidden>Audio service unavailable</p></div>
        <div class="brightness-fixture"><div class="control-label"><span>${icon('sun')}Brightness</span><span class="fixture-tag">Planned</span></div><input type="range" min="0" max="100" value="72" disabled aria-label="Planned brightness control, example data"></div>
        <div class="media-fixture"><span class="album-art" aria-hidden="true">${icon('sun')}</span><div><strong>A little room to breathe</strong><small>Media controls &middot; planned</small></div>${icon('play')}</div>
        <button type="button" class="control-settings" data-open="settings" aria-controls="settings-${concept}" aria-expanded="false" aria-label="Open preview settings">${icon('gear')}<span>Settings<small>Appearance, desktop, and more</small></span>${icon('arrow')}</button>
        <div class="control-footer"><span>${icon('monitor')}NixOS / Hyprland</span><span>Mock data</span></div>
      </section>
      <section class="panel settings-window" id="settings-${concept}" aria-label="Preview Settings window" hidden>
        <div class="settings-titlebar"><span>${icon('distro-nixos')}Senntisten / Settings</span><span class="fixture-tag">Preview window</span><button class="close-button" type="button" data-close="settings" aria-label="Close preview settings">${icon('close')}</button></div>
        <div class="settings-body">
          <nav class="settings-navigation" aria-label="Preview Settings sections"><p class="eyebrow">Preferences</p><button type="button" aria-current="page">${icon('sun')}Appearance</button>${[['monitor', 'Desktop'], ['search', 'Launcher'], ['gear', 'Accessibility']].map(([name, label]) => `<button type="button" disabled>${icon(name)}${label}<small>Planned</small></button>`).join('')}<p class="settings-nav-note">A dedicated window.<br>Not a bigger control panel.</p></nav>
          <div class="settings-content">
            <p class="eyebrow">Personalization</p><h3>Appearance</h3><p class="settings-description">Palettes, wallpaper, and interface preferences.</p>
            <div class="settings-section-heading"><h4>Color palette</h4><span class="fixture-tag">Interactive preview</span></div>
            <div class="palette-picks">${[['catppuccin-mocha', 'Catppuccin Mocha', 'Cool stone. Soft lavender.'], ['gruvbox', 'Gruvbox', 'Warm earth. Burnished gold.']].map(([id, name, description]) => `<button type="button" data-palette="${id}" aria-label="Preview ${name}" aria-pressed="${id === 'catppuccin-mocha'}"><span class="palette-mini" data-preview-palette="${id}" aria-hidden="true"><span class="mini-bar"></span><span class="mini-landscape"></span><span class="mini-panel"></span></span><span class="palette-description"><strong>${name}</strong><small>${description}</small></span>${icon('check')}</button>`).join('')}</div>
            <p class="save-notice" hidden>Example save failure. Nothing was written.</p>
            <div class="settings-preference"><div><h4>Wallpaper</h4><p>Vector landscape in this concept.</p></div><button type="button" disabled>Choose image<span>Planned</span></button></div>
            <div class="settings-preference"><div><h4>Typography</h4><p>Local system fonts in this study.</p></div><button type="button" disabled>Customize<span>Planned</span></button></div>
            <div class="settings-preference"><div><h4>Interface density</h4><p>Spacing and sizing across the shell.</p></div><button type="button" disabled>Configure<span>Planned</span></button></div>
            <p class="settings-motion-note">This study respects your system's reduced-motion preference.</p>
          </div>
        </div>
        <div class="settings-footer">Design preview. No settings are saved.</div>
      </section>
    </div>
    <div class="app-shelf" aria-label="Planned app shelf, non-interactive preview">${['terminal', 'browser', 'folder', 'code'].map(name => `<span class="app-icon" aria-hidden="true">${icon(name)}</span>`).join('')}</div>
    <span class="desktop-footnote">Design fixture / no live services</span>
  </article>
`).join('');

const studies = [...document.querySelectorAll('.desktop-study')];
const palette = document.querySelector('#palette');
const surface = document.querySelector('#surface');
const exampleState = document.querySelector('#example-state');
const feedback = document.querySelector('.review-feedback');
let currentConcept = 'orbit';
let workspace = '2';
let volume = '42';
let settingsOpener = null;
let settingsReturnSurface = 'desktop';

function updatePreview(focusLauncher = false) {
  for (const study of studies) {
    study.hidden = study.dataset.concept !== currentConcept;
    study.dataset.palette = palette.value;
    study.dataset.surface = surface.value;
    study.querySelector('.launcher').hidden = !['overview', 'launcher'].includes(surface.value);
    study.querySelector('.control-panel').hidden = !['overview', 'controls'].includes(surface.value);
    study.querySelector('.settings-window').hidden = surface.value !== 'settings';
    for (const button of study.querySelectorAll('[data-toggle], [data-open]')) {
      button.setAttribute('aria-expanded', String(!study.querySelector(`#${button.getAttribute('aria-controls')}`).hidden));
    }
    for (const button of study.querySelectorAll('[data-palette]')) {
      button.setAttribute('aria-pressed', String(button.dataset.palette === palette.value));
    }
    for (const button of study.querySelectorAll('[data-workspace]')) {
      button.setAttribute('aria-pressed', String(button.dataset.workspace === workspace));
    }
    study.querySelector('.audio-control output').textContent = `${volume}%`;
    study.querySelector('.status-label').textContent = exampleState.value === 'unavailable' ? 'Audio offline' : `${volume}%`;
    const slider = study.querySelector('input[type="range"]');
    slider.value = volume;
    slider.disabled = exampleState.value === 'unavailable';
    study.querySelector('.service-warning').hidden = exampleState.value !== 'unavailable';
    study.querySelector('.save-notice').hidden = exampleState.value !== 'save-error';
  }
  for (const button of document.querySelectorAll('[data-select-concept]')) {
    button.setAttribute('aria-pressed', String(button.dataset.selectConcept === currentConcept));
  }
  const concept = concepts[currentConcept];
  document.querySelector('#concept-number').textContent = concept.number;
  document.querySelector('#concept-title').textContent = concept.title;
  document.querySelector('.concept-heading .eyebrow').textContent = concept.character;
  for (const name of ['presence', 'workflow', 'tradeoff']) {
    document.querySelector(`#${name}-note`).textContent = concept[name];
  }
  if (focusLauncher && ['overview', 'launcher'].includes(surface.value)) {
    studies.find(study => !study.hidden).querySelector('input[type="search"]').focus({ preventScroll: true });
  }
}

document.querySelectorAll('[data-select-concept]').forEach(button => button.addEventListener('click', () => {
  currentConcept = button.dataset.selectConcept;
  settingsOpener = null;
  settingsReturnSurface = 'desktop';
  updatePreview();
  feedback.textContent = `${concepts[currentConcept].title} concept. Design preview only; no choice is saved.`;
}));
palette.addEventListener('change', () => updatePreview());
surface.addEventListener('change', () => {
  settingsOpener = null;
  settingsReturnSurface = 'desktop';
  updatePreview();
});
exampleState.addEventListener('change', () => updatePreview());

for (const study of studies) {
  const search = study.querySelector('input[type="search"]');
  const results = [...study.querySelectorAll('.app-result')];
  let selectedIndex = 0;

  const selectResult = index => {
    const visible = results.filter(result => !result.hidden);
    selectedIndex = visible.length ? Math.max(0, Math.min(index, visible.length - 1)) : -1;
    for (const result of results) result.setAttribute('aria-selected', String(result === visible[selectedIndex]));
    if (visible[selectedIndex]) search.setAttribute('aria-activedescendant', visible[selectedIndex].id);
    else search.removeAttribute('aria-activedescendant');
    return visible[selectedIndex];
  };
  const activate = result => {
    if (result) feedback.textContent = `Preview only: ${result.dataset.app} selected. No application was launched.`;
  };

  search.addEventListener('input', () => {
    const query = search.value.trim().toLowerCase();
    for (const result of results) result.hidden = !`${result.dataset.app} ${result.dataset.keywords}`.toLowerCase().includes(query);
    const count = results.filter(result => !result.hidden).length;
    study.querySelector('.result-count').textContent = `${String(count).padStart(2, '0')} ${count === 1 ? 'result' : 'results'}`;
    study.querySelector('.empty-results').hidden = count > 0;
    selectResult(0);
  });
  search.addEventListener('keydown', event => {
    if (['ArrowDown', 'ArrowUp'].includes(event.key)) {
      event.preventDefault();
      selectResult(selectedIndex + (event.key === 'ArrowDown' ? 1 : -1))?.scrollIntoView({ block: 'nearest' });
    }
    if (event.key === 'Enter') { event.preventDefault(); activate(selectResult(selectedIndex)); }
  });
  results.forEach(result => result.addEventListener('click', () => {
    selectResult(results.filter(entry => !entry.hidden).indexOf(result));
    activate(result);
    search.focus({ preventScroll: true });
  }));
  study.querySelectorAll('[data-toggle], [data-close]').forEach(button => button.addEventListener('click', () => {
    const target = button.dataset.toggle || button.dataset.close;
    if (target === 'settings') {
      surface.value = settingsOpener ? settingsReturnSurface : 'desktop';
      updatePreview();
      (settingsOpener || study.querySelector('[data-open="settings"]')).focus({ preventScroll: true });
      settingsOpener = null;
      return;
    }
    const launcherOpen = ['overview', 'launcher'].includes(surface.value);
    const controlsOpen = ['overview', 'controls'].includes(surface.value);
    const nextLauncher = target === 'launcher' ? !button.dataset.close && !launcherOpen : launcherOpen;
    const nextControls = target === 'controls' ? !button.dataset.close && !controlsOpen : controlsOpen;
    surface.value = nextLauncher && nextControls ? 'overview' : nextLauncher ? 'launcher' : nextControls ? 'controls' : 'desktop';
    updatePreview(nextLauncher && target === 'launcher');
    if (button.dataset.close) study.querySelector(`[data-toggle="${target}"]`).focus({ preventScroll: true });
  }));
  study.querySelectorAll('[data-open="settings"]').forEach(button => button.addEventListener('click', () => {
    if (surface.value === 'settings') {
      study.querySelector('[data-close="settings"]').click();
      return;
    }
    settingsOpener = button;
    settingsReturnSurface = surface.value;
    surface.value = 'settings';
    updatePreview();
    study.querySelector('.settings-window [data-palette]').focus({ preventScroll: true });
  }));
  study.querySelectorAll('[data-palette]').forEach(button => button.addEventListener('click', () => {
    palette.value = button.dataset.palette;
    updatePreview();
    feedback.textContent = `${palette.selectedOptions[0].textContent} preview. No appearance file was written.`;
  }));
  study.querySelectorAll('[data-workspace]').forEach(button => button.addEventListener('click', () => {
    workspace = button.dataset.workspace;
    updatePreview();
    feedback.textContent = `Preview workspace ${workspace}. Your actual Hyprland workspace was not changed.`;
  }));
  study.querySelector('input[type="range"]').addEventListener('input', event => {
    volume = event.target.value;
    updatePreview();
  });
}
document.addEventListener('keydown', event => {
  if (event.key === 'Escape' && !event.defaultPrevented && event.target.closest?.('.desktop-study:not([hidden])') && surface.value !== 'desktop') {
    event.preventDefault();
    if (surface.value === 'settings') {
      studies.find(study => !study.hidden).querySelector('[data-close="settings"]').click();
      return;
    }
    const target = event.target.closest('.control-panel, [data-toggle="controls"]') ? 'controls' : 'launcher';
    surface.value = 'desktop';
    updatePreview();
    studies.find(study => !study.hidden).querySelector(`[data-toggle="${target}"]`).focus({ preventScroll: true });
  }
});
updatePreview();
