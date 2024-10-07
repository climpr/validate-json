# Validate Json

This action validates JSON files against their specified schemas.
It supports both the `$schema` property as well as the `json.schemas` associations settings in VS Code.

## How to use this action

Create a workflow in your repository incorporating this action.

```yaml
# File: .github/workflows/validate-json.yaml
name: Validate Json

on:
  workflow_dispatch:
  pull_request:

jobs:
  run-tests:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Validate Json
        uses: climpr/validate-json@v0
```
