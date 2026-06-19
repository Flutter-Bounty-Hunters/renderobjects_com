# RenderObjects.com
Articles and guides to help developers create their own `RenderObject`s.

## Local Development

Install the Jaspr CLI:
```sh
dart pub global activate jaspr_cli
```


## Build
```sh
jaspr build
```

Output is written to `build/jaspr/`.

## Serve Locally
```sh
jaspr serve
```

Available locally at `http://localhost:8080`.

## Deploy to Production

Merging to `main` automatically builds and deploys the site to [renderobjects.com](https://renderobjects.com) via GitHub Actions and GitHub Pages.

To deploy, open a PR against `main` and merge it. The deployment workflow runs on every push to `main`; progress is visible under the repo's **Actions** tab.

