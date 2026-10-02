
## 2026-09-18: overwrote a file Andrew had placed by hand

While confirming that study 250 (Duncan et al. 2018) was a report, I found a live copy online and curl'd it straight to `kraft-2023-data/studies/pdf/250-duncan-2018.pdf` without checking whether that path already existed. Andrew had already put his own copy there. Rule: before writing to any path in a folder the user fills by hand (`studies/pdf/` especially), list the target first; if it exists, leave it alone and validate it instead of replacing it. When the user says "I did X," the job is verification, not redoing X.

## 2026-10-02: shipped a new page without cache-busting its shared assets

The rounds page went live and a returning visitor saw only its controls: the browser had cached the old `engine.js` and `style.css` (GitHub Pages sends `max-age=600`), and the new page called `rounds()`, which the cached engine lacked. Rule: when a change to `docs/` touches a shared asset that a new or changed page depends on, bump the `?v=` tag on every page's asset links in the same commit (the engine test, section 7, enforces that the tags exist and match). Verify a deploy in a browser that has visited the old version, not only in a fresh profile.

## 2026-10-02: put results above the inputs on phones; Andrew reversed it

To shorten the scroll to the first result, the design pass moved the explorer's "Drop undone" tiles and main chart above the controls on narrow screens. Andrew pointed out that the numbers mean nothing before the reader has seen the program's settings. Rule: in a tool where the results depend on inputs the reader sets, keep inputs before outputs in reading order on every screen size. Shorten the path in other ways (collapse intros, tighten the controls) rather than putting results first. When a layout change trades reading order for scroll length, name the trade-off and ask before shipping it.
