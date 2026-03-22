# Open Construction Twin

## Setup

1. Install gem dependencies:

```bash
bundle install
```

2. Ensure PostGIS is installed in your PostgreSQL instance.

3. Create and migrate databases:

```bash
bin/rails db:prepare
```

4. Start development processes:

```bash
bin/dev
```

`bin/dev` starts:
- Rails web server
- Solid Queue worker (`bin/jobs start`)
- JavaScript watcher
- Tailwind/CSS watcher
