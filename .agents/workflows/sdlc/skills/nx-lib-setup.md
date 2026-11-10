---
name: nx-lib-setup
description: Use when creating a new NX library in this monorepo (libs/api/ or libs/fe/). Required to avoid NX typescript-sync errors.
---

# NX Library Setup

## Overview

NX v22's `@nx/js:typescript-sync` plugin requires a specific two-file tsconfig structure. Wrong structure blocks ALL `nx typecheck` runs.

## Required File Structure

Every new lib needs:
```
libs/<layer>/<name>/
  project.json
  tsconfig.json        ← outer: references only, no compilerOptions
  tsconfig.lib.json    ← inner: actual compilation config
  src/
    index.ts
    lib/
```

## project.json

```json
{
  "name": "<name>",
  "$schema": "../../../node_modules/nx/schemas/project.schema.json",
  "sourceRoot": "libs/<layer>/<name>/src",
  "projectType": "library",
  "tags": ["<layer>", "backend|frontend"]
}
```

## API lib (NestJS) tsconfig.json

Outer file — references only, no compilerOptions:
```json
{
  "extends": "../../../tsconfig.base.json",
  "files": [],
  "include": [],
  "references": [
    { "path": "../entities" },
    { "path": "./tsconfig.lib.json" }
  ]
}
```

## API lib tsconfig.lib.json

Inner file — actual compilation:
```json
{
  "extends": "../../../tsconfig.base.json",
  "compilerOptions": {
    "baseUrl": ".",
    "rootDir": "src",
    "outDir": "dist",
    "tsBuildInfoFile": "dist/tsconfig.lib.tsbuildinfo",
    "emitDeclarationOnly": true,
    "module": "nodenext",
    "moduleResolution": "nodenext",
    "types": ["node"],
    "target": "es2021",
    "experimentalDecorators": true,
    "emitDecoratorMetadata": true
  },
  "include": ["src/**/*.ts"],
  "references": [
    { "path": "../entities/tsconfig.lib.json" }
  ]
}
```

## FE lib (React) tsconfig.json

```json
{
  "files": [],
  "include": [],
  "references": [
    { "path": "../store-data-access" },
    { "path": "../ui-data-access" },
    { "path": "./tsconfig.lib.json" }
  ],
  "extends": "../../../tsconfig.base.json"
}
```

## FE lib tsconfig.lib.json

```json
{
  "extends": "../../../tsconfig.base.json",
  "compilerOptions": {
    "outDir": "dist",
    "types": ["node", "@nx/react/typings/cssmodule.d.ts", "@nx/react/typings/image.d.ts"],
    "rootDir": "src",
    "jsx": "react-jsx",
    "tsBuildInfoFile": "dist/tsconfig.lib.tsbuildinfo"
  },
  "exclude": ["out-tsc", "dist", "src/**/*.spec.ts", "src/**/*.spec.tsx"],
  "include": ["src/**/*.js", "src/**/*.jsx", "src/**/*.ts", "src/**/*.tsx"],
  "references": [
    { "path": "../store-data-access/tsconfig.lib.json" },
    { "path": "../ui-data-access/tsconfig.lib.json" }
  ]
}
```

## Required: tsconfig.base.json path alias

Add to `compilerOptions.paths` in `tsconfig.base.json`:
```json
"@lhypl/<name>": ["libs/<layer>/<name>/src/index.ts"]
```

## Required: nx.json plugin include

For new `libs/api/<name>/` libs, add to the **second** `@nx/js/typescript` plugin's `include` array in `nx.json`:
```json
"libs/api/<name>/*"
```

Frontend libs are covered by the first plugin (no action needed).

## Common Mistakes

| Mistake | Effect | Fix |
|---|---|---|
| `compilerOptions` in `tsconfig.json` | Workspace out of sync error | Move to `tsconfig.lib.json`, keep outer as references-only |
| `include: ["src/**/*.ts"]` in `tsconfig.json` | Same | Remove from outer file |
| Missing `"path": "./tsconfig.lib.json"` reference | Lib not typechecked | Add to outer tsconfig references |
| Wrong module/moduleResolution | API lib fails to compile | Use `nodenext`/`nodenext` for API, `bundler` inherited from base for FE |
| Forgot `nx.json` include for api lib | `typecheck` target not generated | Add `"libs/api/<name>/*"` to second plugin include |
