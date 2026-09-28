# Intervention explorer

A static page (`index.html`) that starts from the restoration requirement g\*(p), the effect in 2019 SD units a program would need at percentile p to return the 2024 NAEP distribution to 2019, and shows how much of it a hypothetical program closes. Users set:

1. the program effect (2019 SD units, averaged over all percentiles);
2. the share of students treated;
3. how participation varies with prior achievement (five levels, from 4:1 favoring p10 over p90 to 4:1 favoring p90);
4. how the effect varies with prior achievement (same scale);
5. whether the outcome is read on the group (students who started at p, followed through) or the distribution (whoever stands at p afterward, the treated/untreated mixture in `analysis/mixture.R`).

The settings are kept in the URL hash, so a configuration can be shared as a link.

## Files

| File | Role |
|---|---|
| `index.html` | The page: controls, SVG charts, tables. No libraries, no build step. |
| `engine.js` | The computation, a port of `analysis/mixture.R` and `water_fill` in `analysis/alloc-rules.R`. |
| `cells.js` | Data, generated. Do not edit by hand. |

## Updating the data

```
Rscript analysis/10-export-tool-data.R      # from the project root; rewrites docs/cells.js
node analysis/tests/test-tool-engine.mjs    # checks cells.js and engine.js against tables/
```

The test compares the engine with the committed R outputs for proportional allocation (both estimands, every budget, four cells). The two agree to about 1e-13 NAEP points.

## Viewing and hosting

Open `index.html` directly, or serve the folder (`python3 -m http.server -d docs`). For GitHub Pages, set the repository's Pages source to the `main` branch, `/docs` folder.
