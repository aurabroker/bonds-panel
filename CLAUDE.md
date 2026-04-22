# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
npm run dev          # dev server at http://localhost:5173 (auto-opens browser)
npm run build        # production build → dist/
npm test             # run unit tests (Vitest)
npm run test:watch   # watch mode
npm run test:coverage
npm run lint         # ESLint — max-warnings 0, fails CI
npm run lint:fix
npm run format       # Prettier over src/**
```

To run a single test file:
```bash
npx vitest run tests/unit/utils.test.js
```

## Architecture

**Single-page vanilla JS application** with no framework. Two entry points: `index.html` (main dashboard) and `analityka.html` (analytics panel). Both are self-contained — all app logic lives in an inline `<script>` block at the bottom of each HTML file.

Backend is **Supabase v2** (PostgreSQL). The client is initialized at the top of the inline script with `supabase.createClient(SB_URL, SB_KEY, ...)`. All DB calls go directly through the browser SDK.

### Logical sections inside `index.html`

The inline script is organized into numbered sections as comments:
1. **SETUP & UTILS** — Supabase init, `escapeHTML`, `fmt`, `showToast`, `throttleWrite`, global error handlers, `dateDiff`, `bondStatus`, `statusBadge`, global state vars (`isAdmin`, `tenantId`, `allBonds`, …)
2. **API.JS** — `loadAll()`, `loadBonds()`, `loadTuDict()` — fetches from Supabase with server-side pagination (`PAGE_SIZE = 50`, `.range(from, to)`, `{ count: 'exact' }`)
3. **RENDER** — `renderBonds()`, `renderClients()`, `renderInsurers()`, `renderUsers()`, `renderAnalytics()`, `renderPagination()` — all use the generic `renderTable(tbodyId, list, rowFn, emptyMsg, colSpan)` helper
4. **CRUD** — save/delete handlers, all routed through `saveCRUD(table, modalId, payload, id)`
5. **AUTH** — `initApp()`, login/logout, session management

### src/ — extracted pure utilities

`src/utils.js` exports the pure functions also used inside the inline scripts (they are duplicated there for zero-bundler usage). This is the source of truth for unit tests.

`src/types.js` — JSDoc `@typedef` declarations for `Bond`, `Tenant`, `Insurer`, `Profile`, `TuDict`, `Analytics`.

### Database schema conventions

All tables and columns are prefixed `bond_`. Primary key across all tables is `bond_id` (UUID). User roles are stored in `bond_profiles.bond_rola` as `'admin'` or `'klient'`.

### Security model

- **RLS**: enforced via `bp_get_role()` and `bp_get_tenant()` SECURITY DEFINER helpers (see `rls_policies.sql`). Clients see only their tenant's data; only admins can DELETE.
- **Audit log**: PostgreSQL triggers on `bond_bonds`, `bond_tenants`, `bond_insurers`, `bond_profiles` write to `bond_audit_log` via the `fn_audit_log()` SECURITY DEFINER function (see `audit_log.sql`).
- **Client-side guard**: `throttleWrite(key, ms)` prevents rapid-fire writes; `isAdmin` gates delete buttons. These are defence-in-depth — primary enforcement is RLS.
- **XSS**: every user-supplied string going into `innerHTML` must be wrapped in `escapeHTML()`.

### Edge Function

`supabase/functions/rate-limit/index.ts` — Deno function providing server-side write rate limiting (30 writes/min per user). Deploy with `supabase functions deploy rate-limit`. Currently not wired to the frontend — calls would replace direct `saveCRUD` calls.

### SQL migration files

`rls_policies.sql` and `audit_log.sql` must be applied manually via Supabase Dashboard → SQL Editor (network access to the Management API and port 5432 is blocked in this environment). Run `rls_policies.sql` first.
