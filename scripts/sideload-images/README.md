# Overview

Some environments do not have the abiliy to pull all docker images (many reasons, will comeback and enumerate the specifics)

> NOTE: This approach CAN possibly push versions not desired due to stripping version (v1) <!-- TODO: swap out ":" for some other character so version can be retained -->

## Scripts

1. Pull the images in the `array` to the local machine where the images can be pulled

```
./scripts/sideload-images/sideload-pull-local.sh
```

1. Push the tar files to Remote in ~/sideload-images folder

```
./scripts/sideload-images/sideload-push-remote.sh
```

1. Run import on remote system

```
./scripts/sideload-images/sideload-remote-import.sh
```
