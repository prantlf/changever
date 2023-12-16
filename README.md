# Changelog-driven Version Manager

[![Latest version](https://img.shields.io/npm/v/changever)
 ![Dependency status](https://img.shields.io/librariesio/release/npm/changever)
](https://www.npmjs.com/package/changever)

Helps with generating changelog and publishing a new version of a Node.js package.

## Installation

This package is usually installed globally, so that you can use the `changever` executable from any directory:

```sh
$ npm i -g changever
```

Make sure, that you use [Node.js] version 18 or newer.

## Usage

    Usage: changever [options] <command> [parameters]

    Commands:
      init          generate a config file with defaults
      version       prepare the current module for publishing a new version
                    (update changelog, bump version, commit and tag the change)
      publish       publish a new version prepared earlier by `changever version`
                    (push the change and tag, publish package, create gh release)
      release       perform both `changever version` and `changever publish`

    Parameters for version and publish:
      [<version>]   version if the changelog update is disabled
                    (also major, minor or patch for bumping the existing version)

    Options for version, publish and release:
      --no-changes       do not update the changelog
      --no-bump          do not bumpt the version in package.json and in the lock
      --no-commit        do not commit the changes during publishing
      --no-tag           do not tag the commit during publishing
      --no-push          do not push the commit and tag during publishing
      --no-release       do not create a new github release
      --no-failure       do not fail in case of no version change or release
      --nc-args <args>   extra arguments for newchanges, enclosed in quotes
      -y|--yes           answer the push and reelase confirmations with "yes"
      -d|--dry-run       only print what would be done without doing it
      -v|--verbose       print the new changes on the console too

    Common options:
      -c|--config <name>  file name of path of the config file
      -V|--version        print the version of the executable and exits
      -h|--help           print the usage information and exits

    Examples:
      $ changever version
      $ changever publish -vd

## Contributing

In lieu of a formal styleguide, take care to maintain the existing coding style.  Add unit tests for any new or changed functionality. Lint and test your code using Grunt.

## License

Copyright (c) 2023 Ferdinand Prantl

Licensed under the MIT license.

[Node.js]: http://nodejs.org/
