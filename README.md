# Open Construction Twin

## Setup

1. Install gem dependencies:

```bash
bundle install
```

2. Start the local PostGIS database (Docker):

```bash
docker compose up -d db
```

The default database connection for development is:

- `DB_HOST=127.0.0.1`
- `DB_PORT=55432`
- `DB_USER=postgres`
- `DB_PASSWORD=postgres`
- `DB_NAME=open_construction_twin_development`
- `DB_QUEUE_NAME=open_construction_twin_development_queue`
- `DB_TEST_NAME=open_construction_twin_test`

You can override these with environment variables.

3. Install Docker. `pg2b3dm` runs via Docker for self-hosted PostGIS -> 3D Tiles conversion.

```bash
docker pull geodan/pg2b3dm:latest
```

Optional runtime settings:

```bash
export PG2B3DM_DOCKER_IMAGE=geodan/pg2b3dm:latest
export PG2B3DM_DOCKER_NETWORK=host
```

4. Create and migrate databases:

```bash
bin/rails db:prepare
```

5. Start development processes:

```bash
bin/dev
```

`bin/dev` starts:
- Rails web server
- Solid Queue worker (`bin/jobs start`)
- JavaScript watcher
- Tailwind/CSS watcher

## 3D Pipeline Notes

- Each dataset creates exactly one map layer.
- Shapefiles without Z coordinates receive a default height (`28m`) for 3D visualization.
- `ProcessDatasetJob` imports source data into PostGIS and normalizes geometry.
- `Generate3dTilesJob` exports tiles with `pg2b3dm` and publishes under `public/tilesets`.
- Layer metadata and artifact URLs are available at `GET /projects/:project_id/layers`.

## Spatial Extensions

`postgis` and `postgis_sfcgal` are required for 3D tile extrusion.
The migration `db/migrate/20260330100000_enable_spatial_extensions.rb` enforces both.
