async (page) => {
  const assert = (condition, message) => {
    if (!condition) throw new Error(message);
  };
  const checks = [];
  const active = page.locator('.desktop-study:not([hidden])');
  const choose = async (name, value) => page.getByLabel(name, { exact: true }).selectOption(value);

  // Routing bypasses the browser cache so checks exercise the current local files.
  await page.route('**/studies.*', route => route.continue());
  await page.reload();
  await page.getByRole('button', { name: '01 Citadel', exact: true }).click();
  assert(await active.getAttribute('data-concept') === 'citadel', 'Citadel must be visible');
  await page.getByRole('button', { name: '02 Orbit', exact: true }).click();
  assert(await active.getAttribute('data-concept') === 'orbit', 'Orbit must replace Citadel');
  assert(await page.getByRole('button', { name: '02 Orbit', exact: true }).getAttribute('aria-pressed') === 'true', 'Concept selection must be accessible');
  assert(await active.evaluate(el => {
    const desktop = el.getBoundingClientRect();
    const bar = el.querySelector('.desktop-bar');
    const box = bar.getBoundingClientRect();
    return box.top === desktop.top && box.left === desktop.left && box.width === desktop.width && getComputedStyle(bar).borderRadius === '0px';
  }), 'Orbit must have a full-width, edge-integrated bar without floating margins or outer rounding');
  assert(await active.locator('.brand-action use').getAttribute('href') === '#distro-nixos', 'The launcher entry must use the NixOS distro icon, not the Senntisten S');
  assert(await active.locator('.brand-action use').evaluate(el => {
    const bounds = el.getBBox();
    return bounds.width >= 18 && bounds.height >= 18;
  }), 'The local snowflake vector must render with nonempty geometry');
  checks.push('concept selection, non-floating Orbit bar and rendered local NixOS icon');

  for (const concept of ['01 Citadel', '02 Orbit']) {
    await page.getByRole('button', { name: concept, exact: true }).click();
    for (const palette of ['gruvbox', 'catppuccin-mocha']) {
      await choose('Palette', palette);
      const background = await active.evaluate(el => getComputedStyle(el).getPropertyValue('--surface').trim());
      assert(background === (palette === 'gruvbox' ? '#282828' : '#1e1e2e'), 'The palette must change the rendered surface tokens');
      const surfaceSelector = page.getByLabel('Surface', { exact: true });
      await surfaceSelector.focus();
      await choose('Surface', 'launcher');
      assert(await surfaceSelector.evaluate(el => document.activeElement === el), 'Review selectors must retain focus while changing options');
      await surfaceSelector.press('Escape');
      assert(await surfaceSelector.inputValue() === 'launcher', 'Escape outside the desktop must not dismiss preview panels');
      assert(await surfaceSelector.evaluate(el => document.activeElement === el), 'Escape on a review selector must preserve focus');
      const launcherToggle = active.getByRole('button', { name: 'Toggle preview launcher' });
      assert(await launcherToggle.getAttribute('aria-expanded') === 'true', 'Launcher toggle must announce the open panel');
      const panelId = await launcherToggle.getAttribute('aria-controls');
      assert(panelId && await active.locator(`#${panelId}`).isVisible(), 'Launcher toggle must identify its panel');
      await launcherToggle.click();
      assert(await launcherToggle.getAttribute('aria-expanded') === 'false', 'Launcher toggle must announce the closed panel');
      await launcherToggle.click();
      const search = active.getByRole('searchbox', { name: 'Search preview applications' });
      assert(await search.evaluate(el => document.activeElement === el), 'Opening the launcher must focus search');
      await search.fill('term');
      assert(await active.locator('.app-result:not([hidden])').count() === 1, 'Search must filter preview applications');
      await search.press('Enter');
      assert((await page.getByRole('status').last().textContent()).includes('No application was launched'), 'Activation must explicitly remain a simulation');
      await search.fill('no-such-application');
      assert(await active.getByText('No matching preview applications.', { exact: true }).isVisible(), 'Empty search must explain itself');
      await search.fill('');
      await search.press('ArrowDown');
      assert(await active.locator('.app-result[aria-selected="true"]').getAttribute('data-app') === 'Firefox', 'Arrow keys must move the result selection');
      await search.press('Escape');
      assert(!(await active.locator('.launcher').isVisible()), 'Escape must close the launcher');
    }
  }
  checks.push('both palettes, search, keyboard selection, simulated activation, scoped Escape, toggle state, and focus in both concepts');

  await choose('Surface', 'controls');
  assert(await active.getByRole('button', { name: 'Toggle preview controls' }).getAttribute('aria-expanded') === 'true', 'Controls toggle must announce the open panel');
  assert(await active.getByRole('button', { name: 'Preview settings', exact: true }).getAttribute('aria-expanded') === 'false', 'Settings must be separate from Quick Controls');
  assert(await active.locator('.control-panel [data-palette]').count() === 0, 'Quick Controls must not contain appearance preferences');
  await choose('Example state', 'unavailable');
  assert(await active.getByRole('slider', { name: 'Preview output volume' }).isDisabled(), 'Unavailable audio must disable its control');
  assert(await active.getByText('Audio service unavailable', { exact: true }).isVisible(), 'Unavailable service must be visible');
  await choose('Example state', 'normal');
  const volume = active.getByRole('slider', { name: 'Preview output volume' });
  await volume.press('End');
  for (let step = 0; step < 35; step++) await volume.press('ArrowLeft');
  assert(await active.locator('.audio-control output').textContent() === '65%', 'Volume must update the simulated readout');
  await active.getByRole('button', { name: 'Preview workspace 3', exact: true }).click();
  assert(await active.getByRole('button', { name: 'Preview workspace 3', exact: true }).getAttribute('aria-pressed') === 'true', 'Workspace selection must update');
  checks.push('unavailable service, simulated audio and workspace, no appearance controls in Quick Controls');

  for (const concept of ['01 Citadel', '02 Orbit']) {
    await page.getByRole('button', { name: concept, exact: true }).click();
    await choose('Surface', 'controls');
    await active.getByRole('slider', { name: 'Preview output volume' }).press('Escape');
    assert(!(await active.locator('.control-panel').isVisible()), 'Escape must close Quick Controls');
    assert(await active.getByRole('button', { name: 'Toggle preview controls' }).evaluate(el => document.activeElement === el), 'Escape from Quick Controls must restore focus to its own toggle');
    await choose('Surface', 'controls');
    const openSettings = active.getByRole('button', { name: 'Open preview settings', exact: true, includeHidden: true });
    await openSettings.click();
    const settings = active.getByRole('region', { name: 'Preview Settings window', exact: true });
    assert(await settings.isVisible(), 'Quick Controls must open a dedicated Settings window');
    assert(!(await active.locator('.control-panel').isVisible()), 'Settings must not be embedded in Quick Controls');
    assert(await openSettings.getAttribute('aria-expanded') === 'true', 'The Settings entry must announce its window state');
    assert(await settings.getByRole('button', { name: 'Preview Catppuccin Mocha' }).evaluate(el => document.activeElement === el), 'Opening Settings must focus an interactive preference');
    await settings.getByRole('button', { name: 'Preview Gruvbox' }).click();
    assert(await page.getByLabel('Palette', { exact: true }).inputValue() === 'gruvbox', 'Settings palette selection must update the preview');
    await choose('Example state', 'save-error');
    assert(await settings.getByText('Example save failure. Nothing was written.', { exact: true }).isVisible(), 'Save failure must be shown in Settings');
    await settings.getByRole('button', { name: 'Close preview settings' }).click();
    assert(await active.locator('.control-panel').isVisible(), 'Closing Settings must restore the invoking Quick Controls surface');
    assert(await openSettings.evaluate(el => document.activeElement === el), 'Closing Settings must restore focus to its entry');
    await openSettings.click();
    await settings.getByRole('button', { name: 'Preview Gruvbox' }).press('Escape');
    assert(!(await settings.isVisible()) && await openSettings.evaluate(el => document.activeElement === el), 'Escape in Settings must restore the invoking surface and focus');
    await choose('Example state', 'normal');
  }
  checks.push('separate Settings, palette selection, save failure, Quick Controls and Settings close/Escape focus restoration in both concepts');

  await choose('Surface', 'overview');
  for (const concept of ['01 Citadel', '02 Orbit']) {
    await page.getByRole('button', { name: concept, exact: true }).click();
    for (const width of [1440, 1024, 768, 665, 651, 390, 320]) {
      await page.setViewportSize({ width, height: 960 });
      assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), `${concept} must not overflow at ${width}px`);
      for (const selector of ['.launcher', '.control-panel']) {
        const box = await active.locator(selector).boundingBox();
        assert(box && box.width >= Math.min(240, width - 40) && box.x >= 0 && box.x + box.width <= width + 1, `${selector} must remain readable and inside the viewport`);
      }
      await choose('Example state', 'unavailable');
      assert(await active.evaluate(el => {
        const clock = el.querySelector('.bar-clock');
        if (getComputedStyle(clock).display === 'none') return true;
        return clock.getBoundingClientRect().right <= el.querySelector('.bar-right').getBoundingClientRect().left;
      }), `${concept} clock must not collide with unavailable-audio controls at ${width}px`);
      await choose('Example state', 'normal');
      for (const button of await active.locator('[data-workspace]').all()) {
        const box = await button.boundingBox();
        assert(box.width >= 24 && box.height >= 24, 'Workspace indicators need at least 24px pointer targets');
      }
      if (concept === '02 Orbit') assert(await active.evaluate(el => {
        const bar = el.querySelector('.desktop-bar').getBoundingClientRect();
        const desktop = el.getBoundingClientRect();
        return bar.left === desktop.left && bar.top === desktop.top && bar.width === desktop.width;
      }), `Orbit's bar must remain edge-integrated at ${width}px`);
      if (concept === '02 Orbit') {
        const errors = await active.evaluate(el => {
          const errors = [];
          const box = selector => el.querySelector(selector).getBoundingClientRect();
          const aligned = (a, b) => Math.abs(a - b) <= 1;
          const launcher = box('.launcher'), controls = box('.control-panel');
          if (!aligned(launcher.left, controls.left) && !aligned(launcher.top, controls.top)) errors.push('panel top edges');
          const search = box('.search-field'), results = box('.results');
          if (!aligned(search.left, results.left) || !aligned(search.right, results.right)) errors.push('search/result gutters');
          const searchIcon = box('.search-field > .icon'), appIcon = box('.results .app-icon');
          if (!aligned(searchIcon.left + searchIcon.width / 2, appIcon.left + appIcon.width / 2)) errors.push('launcher icon columns');
          if (!aligned(box('.search-field input').left, box('.app-copy').left)) errors.push('launcher text columns');
          const rowHeights = [...el.querySelectorAll('.app-result')].map(row => row.getBoundingClientRect().height);
          if (!aligned(Math.min(...rowHeights), Math.max(...rowHeights))) errors.push('consistent result rows');
          for (const tile of el.querySelectorAll('.status-tile')) {
            const tag = tile.querySelector('.planned-tag').getBoundingClientRect();
            const icon = tile.querySelector('.icon').getBoundingClientRect();
            if (tag.height && !aligned(tag.top + tag.height / 2, icon.top + icon.height / 2)) errors.push('status badge alignment');
          }
          const clock = el.querySelector('.bar-clock');
          if (getComputedStyle(clock).display !== 'none') {
            const range = document.createRange();
            range.selectNode(clock.firstChild);
            const time = range.getBoundingClientRect();
            range.selectNodeContents(clock.querySelector('span'));
            const date = range.getBoundingClientRect();
            if (!aligned(time.top + time.height / 2, date.top + date.height / 2)) errors.push('clock/date alignment');
          }
          return errors;
        });
        assert(errors.length === 0, `Orbit alignment at ${width}px: ${errors.join(', ')}`);
      }
      await choose('Surface', 'settings');
      const settingsBox = await active.locator('.settings-window').boundingBox();
      assert(settingsBox && settingsBox.x >= 0 && settingsBox.x + settingsBox.width <= width + 1 && settingsBox.width >= Math.min(240, width - 40), `Settings must remain readable at ${width}px`);
      assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), `Settings must not overflow at ${width}px`);
      if (concept === '02 Orbit') {
        assert(await active.evaluate(el => {
          const actions = [...el.querySelectorAll('.settings-preference button')].map(button => button.getBoundingClientRect());
          return actions.every(box => Math.abs(box.left - actions[0].left) <= 1 && Math.abs(box.width - actions[0].width) <= 1);
        }), `Settings action columns must align at ${width}px`);
        assert(await active.evaluate(el => {
          const title = el.querySelector('.settings-titlebar > span').getBoundingClientRect();
          const range = document.createRange();
          range.selectNodeContents(el.querySelector('.settings-footer'));
          return Math.abs(title.left - range.getBoundingClientRect().left) <= 1;
        }), `Settings title/footer gutters must align at ${width}px`);
      }
      await choose('Surface', 'overview');
    }
  }
  checks.push('both concepts and Settings at seven widths from 320 to 1440px, Orbit alignment, edge bar, unavailable-audio collisions and pointer targets');

  await page.emulateMedia({ reducedMotion: 'reduce' });
  assert(await active.evaluate(el => getComputedStyle(el).transitionDuration === '0s'), 'Reduced motion must disable preview transitions');
  await page.emulateMedia({ reducedMotion: null });
  await page.setViewportSize({ width: 1440, height: 1100 });
  await page.getByRole('button', { name: '02 Orbit', exact: true }).click();
  await choose('Palette', 'catppuccin-mocha');
  await choose('Surface', 'overview');
  checks.push('reduced motion');
  await page.unroute('**/studies.*');
  return { passed: checks.length, checks };
}
