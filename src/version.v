import os { exists, join_path_single, write_file }
import semver { Increment }
import prantlf.debug { rwd }
import prantlf.jany { Any, any_null }
import prantlf.json { StringifyOpts, stringify }
import prantlf.osutil { ExecuteOpts, execute, execute_opt }
import prantlf.pcre { pcre_compile }
import prantlf.strutil { last_line_not_empty, until_last_nth_line_not_empty }

const re_verline = pcre_compile(r'^version ((?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*))',
	0)!

fn create_version(version string, commit bool, tag bool, opts &Opts) !(string, string) {
	pkg_dir, pkg_file, pkg := if !opts.changes || opts.bump {
		dir, file := find_package()!
		dir, file, read_json(file)!
	} else {
		'', '', any_null()
	}

	mode := if opts.dry_run {
		'd'
	} else {
		''
	}
	mut ver := ''
	mut log := ''
	if opts.changes {
		out := execute_opt('newchanges -Nuv${mode} ${opts.nc_args}', ExecuteOpts{
			trim_trailing_whitespace: true
		})!
		log = until_last_nth_line_not_empty(out, 2)
		line := last_line_not_empty(out)
		if opts.verbose {
			println(out)
		} else {
			println(line)
		}
		if line.starts_with('no ') {
			msg := 'version not upgraded'
			if opts.failure {
				return error(msg)
			}
			println(msg)
			return '', ''
		}
		ver = if m := re_verline.exec(line, 0) {
			m.group_text(line, 1) or { return unreachable() }
		} else {
			return error('unexpected output of newchanges: "${line}"')
		}
	} else {
		ver = get_next_version(version, &pkg)!
	}

	if opts.bump {
		set_version(ver, pkg_dir, pkg_file, &pkg, opts)!
	}

	do_commit(ver, commit, tag, opts)!

	return ver, log
}

fn do_commit(ver string, commit bool, tag bool, opts &Opts) ! {
	mode := if opts.dry_run {
		' (dry-run)'
	} else {
		''
	}

	if commit {
		if tag {
			out := execute_opt('git tag -l "v${ver}"', ExecuteOpts{
				trim_trailing_whitespace: true
			})!
			d.log_str(out)
			if out.len > 0 {
				msg := 'tag v${ver} already exists'
				if opts.failure {
					return error(msg)
				}
				println(msg)
				return
			}
		}

		if opts.dry_run {
			println('prepared version ${ver} for committing${mode}')
			return
		}

		mut out := execute('git commit -am "${ver} [skip ci]"')!
		d.log_str(out)
		eprintln('')

		if tag {
			out = execute('git tag -a "v${ver}" -m "${ver}"')!
			d.log_str(out)

			println('prepared version ${ver} for pushing')
		} else {
			println('prepared version ${ver} for tagging')
		}
	} else {
		println('prepared version ${ver} for committing${mode}')
	}
}

fn get_next_version(new_ver string, pkg &Any) !string {
	if new_ver.len == 0 {
		return error('updating the changelog was disabled, specify the new version on the command line')
	}

	ver_any := pkg.object()!['version'] or {
		return error('package descriptor contains no version')
	}
	ver := ver_any.string()!
	return if increment := get_increment(new_ver) {
		if ver.len == 0 {
			return error('package descriptor contains empty version')
		}
		orig_ver := semver.from(ver)!
		orig_ver.increment(increment).str()
	} else {
		semver.from(new_ver)!
		if ver == new_ver {
			return error('${new_ver} is the current version')
		}
		new_ver
	}
}

fn get_increment(version string) ?Increment {
	return match version {
		'major' {
			Increment.major
		}
		'minor' {
			Increment.minor
		}
		'patch' {
			Increment.patch
		}
		else {
			none
		}
	}
}

fn set_version(ver string, pkg_dir string, pkg_file string, pkg &Any, opts &Opts) ! {
	d.log('setting version to "%s"', version)
	pkg.object()!['version'] = ver

	lck_file := join_path_single(pkg_dir, 'package-lock.json')
	lck_is := exists(lck_file)
	mut lck := any_null()
	if lck_is {
		lck = read_json(lck_file)!
		lck.object()!['version'] = ver
		lck.set('packages."".version', Any(ver))!
	}

	if !opts.dry_run {
		dpkg_file := d.rwd(pkg_file)
		d.log('writing file "%s"', dpkg_file)
		text := stringify(pkg, StringifyOpts{ pretty: true })
		write_file(pkg_file, text)!

		if lck_is {
			dlck_file := d.rwd(lck_file)
			d.log('writing file "%s"', dlck_file)
			text2 := stringify(lck, StringifyOpts{ pretty: true })
			write_file(lck_file, text2)!
		}
	}

	if opts.verbose {
		mut mode := if opts.dry_run {
			' (dry-run)'
		} else {
			''
		}
		if lck_is {
			mode = ' and "${rwd(lck_file)}"${mode}'
		}
		println('updated version in "${rwd(pkg_file)}"${mode}')
	}
}
