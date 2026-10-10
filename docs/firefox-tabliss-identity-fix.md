# Firefox — Remove `Extension (Tabliss)` Button on New Tabs

That `Extension (Tabliss)` pill in the address bar is Firefox's Site Identity button.

Because Tabliss overrides your New Tab with a `moz-extension://` page, Firefox shows it on every new tab. It's a security feature — there is no setting to turn it off. Hide it with `userChrome.css`, or remove Tabliss.

## Option 1: Hide with userChrome.css (keeps Tabliss)

1. Go to `about:config` → set `toolkit.legacyUserProfileCustomizations.stylesheets` to `true`
2. Go to `about:support` → Profile Folder → Open Folder
3. Create a folder named `chrome` inside it
4. Inside `chrome`, create `userChrome.css` with:

```css
#identity-box.extensionPage #identity-icon-labels,
#identity-box.extensionPage #identity-icon-label {
  visibility: collapse !important;
}
```

5. Restart Firefox.

Result: hides the `Extension (Tabliss)` text, keeps the icon, shows text on hover.

## Option 2: Remove Tabliss (back to default New Tab)

- `about:addons` → Tabliss → Remove, or
- `Settings → Home → New Tabs` → Disable Extension

## Notes

- Filename must be exactly `userChrome.css` (not `.css.txt`).
- Applies to all extension pages, not just Tabliss.
- Breaks on major Firefox UI refactors — re-check `#identity-box.extensionPage` selector if it stops working.
