import prantlf.cli { Cli, Env, run }
import prantlf.debug { new_debug }

const version = '0.1.0'

const usage = 'Changelog-driven version manager - helps with generating changelog and publishing a new version of a Node.js package.

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
  $ changever publish -vd'

struct Opts {
	changes   bool = true
	bump      bool = true
	commit    ?bool
	tag       ?bool
	push      bool = true
	release   bool = true
	failure   bool = true
	nc_args   string @[json: 'nc-args']
	yes       bool
	dry_run   bool   @[json: 'dry-run']
	verbose   bool
	gh_token  string @[json: 'gh-token']
	npm_token string @[json: 'npm-token']
}

const d = new_debug('vp')

fn main() {
	run(Cli{
		usage: usage
		version: version
		options_anywhere: true
		cfg_opt: 'c'
		cfg_gen_arg: 'init'
		cfg_file: '.changever'
		env: Env.both
	}, body)
}

fn body(mut opts Opts, args []string) ! {
	if args.len == 0 {
		return error('Command is missing.')
	}

	first_arg := if args.len > 1 {
		args[1]
	} else {
		''
	}

	command := args[0]
	match command {
		'version' {
			commit := opts.commit or { true }
			tag := opts.tag or { true }
			create_version(first_arg, commit, tag, &opts)!
		}
		'publish' {
			commit := opts.commit or { false }
			tag := opts.tag or { false }
			publish(commit, tag, &opts)!
		}
		'release' {
			commit := opts.commit or { true }
			tag := opts.tag or { true }
			version_and_publish(first_arg, commit, tag, &opts)!
		}
		else {
			return error('Command "${command}" is invalid.')
		}
	}
}
