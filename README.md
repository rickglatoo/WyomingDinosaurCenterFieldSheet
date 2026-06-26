# WDC Field Collection App

A progressive web app (PWA) for field specimen collection at the **Wyoming Dinosaur Center**. Built for iPad and iPhone, works offline in the field, and syncs to a cloud database when connectivity is available.

![WDC Field App](WDC_fieldApp.png)

---

## Overview

Field teams use this app to log paleontological specimens at the moment of discovery. Every record follows the [Darwin Core](https://dwc.tdwg.org/) standard with the [PaleoContext extension](https://tdwg.github.io/paleo/), making WDC data compatible with iDigBio, GBIF, and the Paleobiology Database without transformation.

---

## Features

- **Offline-first** — works with no connectivity; syncs automatically when back in range
- **Darwin Core aligned** — all fields map directly to DwC / PaleoContext terms
- **Chain of custody** — every specimen gets an immutable custody event log from discovery onward
- **GPS + compass capture** — tap to fill coordinates and specimen orientation from device sensors
- **Photo management** — capture or pick photos, stored in Supabase Storage under `{site}/{specimen}/`
- **Role-based access** — collector, manager, and admin roles enforced at the database level
- **Radial map points** — up to 4 reference point measurements (A–D) per specimen
- **Auto catalog numbers** — format `{SITE}-{YYYY}-{###}`, scans existing records to prevent duplicates

---

## Tech Stack

| Layer | Service |
|-------|---------|
| Database & Auth | [Supabase](https://supabase.com) (PostgreSQL + Auth + Storage) |
| Hosting | [GitHub Pages](https://pages.github.com) |
| Standards | Darwin Core · PaleoContext Extension |
| Runtime | Vanilla JS PWA — no framework, no build step |

---

## Project Structure

```
wdc-field/
├── index.html              # Complete single-file PWA
├── sw.js                   # Service worker (offline caching)
├── WDC_fieldApp.png        # Splash screen image
├── supabase-schema.sql     # Full database schema — run once in Supabase SQL Editor
├── SCHEMA.md               # Complete schema reference and Darwin Core crosswalk
├── README.md               # This file
└── old/                    # Archived v1 files (Google Sheets / Cloudflare Worker)
```

---

## Database Schema

The schema lives in `supabase-schema.sql`. Five tables:

| Table | DwC Class | Description |
|-------|-----------|-------------|
| `profiles` | — | Users and roles |
| `locations` | Location | Dig sites |
| `occurrences` | Occurrence + Event + Taxon + GeologicContext | Specimen records |
| `custody_events` | — | Immutable chain-of-custody log |
| `media` | associatedMedia | Photos and files |

See `SCHEMA.md` for the full field-by-field reference including Darwin Core term mappings.

---

## Setup

### 1. Database

1. Create a [Supabase](https://supabase.com) project
2. Open **SQL Editor** → paste the contents of `supabase-schema.sql` → **Run**
3. Go to **Authentication → Users → Add user** and create your account
4. Promote yourself to admin:
   ```sql
   update profiles set role = 'admin'::user_role
   where email = 'your@email.com';
   ```

### 2. App configuration

Update the Supabase credentials in `index.html` (top of the `<script>` block):

```javascript
const SUPABASE_URL  = 'https://your-project.supabase.co';
const SUPABASE_ANON = 'your-anon-public-key';
```

### 3. Deploy

Push to GitHub. Enable **GitHub Pages** from the repo settings (source: main branch, root directory). The app is live at `https://{username}.github.io/{repo}/`.

---

## User Roles

| Role | Permissions |
|------|-------------|
| `collector` | Create occurrences and locations; edit own records |
| `manager` | Edit any record; delete media |
| `admin` | Full access; manage users; delete records |

All permissions are enforced by Supabase Row Level Security — not just the UI.

---

## Darwin Core Alignment

Field app labels map to standard DwC terms:

| App Label | Database Column | Darwin Core Term |
|-----------|----------------|-----------------|
| Specimen # | `catalog_number` | catalogNumber |
| Date Discovered | `event_date` | eventDate |
| Collector | `recorded_by` | recordedBy |
| Taxon | `scientific_name` | scientificName |
| Formation | `formation` | formation |
| Associations | `associated_occurrences` | associatedOccurrences |
| GPS | `decimal_latitude` / `decimal_longitude` | decimalLatitude / decimalLongitude |

Full crosswalk in `SCHEMA.md`.

---

## Roadmap

- [x] Phase 1 — Field Collection App (this app)
- [ ] Phase 2 — Preparation Lab App
- [ ] Phase 3 — Collections Catalog App
- [ ] Phase 4 — Admin & Reporting
- [ ] Phase 5 — Public Research Portal

---

## Contributing

This project is developed on a volunteer basis for the Wyoming Dinosaur Center. All specimen data is proprietary to WDC.

---

*Wyoming Dinosaur Center · Thermopolis, Wyoming*
