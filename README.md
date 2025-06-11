# 3p-openjpeg

This repository contains an autobuild-vendored version of [OpenJPEG](https://www.openjpeg.org/) used by Second Life.

## Overview

OpenJPEG is an open-source JPEG 2000 codec written in C language. This repository packages it for use with Second Life's [autobuild](https://github.com/secondlife/autobuild) system.

The OpenJPEG source code is included as a git submodule pointing to the upstream repository at [https://github.com/uclouvain/openjpeg](https://github.com/uclouvain/openjpeg).

## Usage

This package is consumed by Second Life's build system through autobuild. The built artifacts include:

- Static/dynamic libraries (`libopenjp2` with platform-specific extensions)
- Header files for JPEG 2000 codec functionality
- License and copyright information

To use this package in an autobuild-based project:

```bash
autobuild install openjpeg
```

## Building Locally

To build this package locally:

1. Ensure you have autobuild installed and configured
2. Clone the repository with submodules:
   ```bash
   git clone --recursive https://github.com/secondlife/3p-openjpeg.git
   ```
3. Build the package:
   ```bash
   autobuild build
   ```

## License

OpenJPEG is licensed under the BSD license. See `openjpeg/LICENSE` for full license text.

## Contributing

This repository follows the standard Second Life third-party package conventions:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test across all supported platforms
5. Submit a pull request

For issues related to the OpenJPEG library itself, please report them to the [upstream OpenJPEG repository](https://github.com/uclouvain/openjpeg).
