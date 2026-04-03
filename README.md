# ☯️ `jsonc-merge`

`jsonc-merge` is now a **compatibility shim** for [`json-merge`](https://github.com/kettle-rb/json-merge).

`json-merge` now handles both JSON and JSONC in this workspace, including comment-preserving merge behavior when the underlying parser exposes JSONC comments. This gem remains available only to preserve the legacy:

- gem name: `jsonc-merge`
- require path: `require "jsonc/merge"`
- namespace: `Jsonc::Merge`

If you are starting fresh, use `json-merge` instead.

## Status

- ✅ Existing `jsonc-merge` consumers continue to work.
- ✅ `require "jsonc/merge"` forwards to `json-merge`.
- ✅ `Jsonc::Merge::SmartMerger` aliases `Json::Merge::SmartMerger`.
- ⚠️ New development and format-specific documentation now belong in `json-merge`.

## Recommended installation for new projects

```ruby
gem "json-merge"
```

```ruby
require "json/merge"
```

See [`json-merge` README](https://github.com/kettle-rb/json-merge/blob/main/README.md) for installation, parser/runtime requirements, configuration, and merge examples.

## Migration

Move from the legacy shim to the main gem when convenient:

```ruby
# before
gem "jsonc-merge"
require "jsonc/merge"
```

```ruby
# after
gem "json-merge"
require "json/merge"
```

Most callers do not need code changes beyond the gem name, require path, and optional namespace rename from `Jsonc::Merge` to `Json::Merge`.

## Legacy compatibility

This shim intentionally keeps older integrations working:

```ruby
require "jsonc/merge"

template = <<~JSONC
  {
    "name": "template",
    "added": true
  }
JSONC

destination = <<~JSONC
  // legacy shim path still works
  {
    "name": "destination" // inline comment
  }
JSONC

merged = Jsonc::Merge::SmartMerger.new(
  template,
  destination,
  add_template_only_nodes: true,
).merge
```

The merge behavior comes from `json-merge`; this gem only preserves the legacy entrypoints.

## Project links

- [`json-merge`](https://github.com/kettle-rb/json-merge)
- [`CHANGELOG.md`](CHANGELOG.md)
- [`SECURITY.md`](SECURITY.md)
- [`CONTRIBUTING.md`](CONTRIBUTING.md)
- [`LICENSE.txt`](LICENSE.txt)
