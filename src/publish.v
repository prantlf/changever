import os { create, exists, getenv_opt, home_dir, join_path_single, read_lines }
import prantlf.github { create_release, find_git, get_gh_token, get_release, get_repo_path }
import prantlf.osutil { ExecuteOpts, execute, execute_opt }
import prantlf.strutil { last_line_not_empty, until_one_but_last_line_not_empty }

fn publish(commit bool, tag bool, opts &Opts) ! {
	ver, log := if opts.release {
		get_last_version(opts)!
	} else {
		v := get_current_version()!
		if v.len == 0 {
			return error('package descriptor contains no version')
		}
		v, ''
	}
	if ver.len > 0 {
		if commit {
			do_commit(ver, commit, tag, opts)!
		}
		do_publish(ver, log, opts)!
	}
}

fn get_last_version(opts &Opts) !(string, string) {
	out := execute_opt('newchanges -iv ${opts.nc_args}', ExecuteOpts{
		trim_trailing_whitespace: true
	})!
	log := until_one_but_last_line_not_empty(out)
	line := last_line_not_empty(out)
	if opts.verbose {
		println(out)
	} else {
		println(line)
	}
	if line.starts_with('no ') {
		msg := 'version not found'
		if opts.failure {
			return error(msg)
		}
		println(msg)
		return '', ''
	}
	ver := if m := re_verline.exec(line, 0) {
		m.group_text(line, 1) or { panic(err) }
	} else {
		return error('unexpected output of newchanges: "${line}"')
	}

	return ver, log
}

fn do_publish(ver string, log string, opts &Opts) ! {
	publish_package(ver, opts)!

	repo_path, gh_token := if opts.release {
		path := find_git()!
		repo := get_repo_path(path)!
		token := if opts.gh_token.len > 0 {
			opts.gh_token
		} else {
			get_gh_token()!
		}
		if get_release(repo, token, 'v${ver}')!.len > 0 {
			msg := 'version ${ver} has been already released'
			if opts.failure {
				return error(msg)
			}
			println(msg)
			return
		}
		repo, token
	} else {
		'', ''
	}

	mode := if opts.dry_run {
		' (dry-run)'
	} else {
		''
	}

	if opts.push && (opts.yes || confirm('push version ${ver}${mode}')!) {
		if !opts.dry_run {
			out := execute('git push --atomic origin HEAD "v${ver}"')!
			d.log_str(out)
			eprintln('')
		}
		println('pushed version ${ver}${mode}')
	}

	if opts.release {
		if opts.yes || confirm('release version ${ver}${mode}')! {
			if !opts.dry_run {
				create_release(repo_path, gh_token, 'v${ver}', ver, log)!
			}
			println('released version ${ver}${mode}')
		}
	}
}

fn publish_package(ver string, opts &Opts) ! {
	was_authenticated, glob_npmrc, npmrc := authenticate(opts)!
	defer {
		if was_authenticated {
			set_auth_token(glob_npmrc, npmrc, '') or { eprintln(err.msg()) }
		}
	}

	mode := if opts.dry_run {
		' (dry-run)'
	} else {
		''
	}

	if opts.yes || confirm('publish version ${ver}${mode}')! {
		mut extra_args := if opts.verbose { ' --verbose' } else { ' --quiet' }
		if opts.dry_run {
			extra_args += ' --dry-run'
		}
		out := execute('npm publish --access public${extra_args}')!
		println(out)
	}
}

fn authenticate(opts &Opts) !(bool, string, []string) {
	mut is_authenticated := false
	mut npmrc := []string{}
	glob_npmrc := join_path_single(home_dir(), '.npmrc')
	if exists(glob_npmrc) {
		npmrc = read_npmrc(glob_npmrc)!
		is_authenticated = has_auth_token(npmrc)!
	}
	if !is_authenticated {
		pkg_dir, _ := find_package()!
		loc_npmrc := join_path_single(pkg_dir, '.npmrc')
		if exists(loc_npmrc) {
			npmrc2 := read_npmrc(loc_npmrc)!
			is_authenticated = has_auth_token(npmrc2)!
		}
	}

	if is_authenticated {
		return false, '', []string{}
	}

	token := if opts.npm_token.len > 0 {
		opts.npm_token
	} else {
		get_npm_token()!
	}
	set_auth_token(glob_npmrc, npmrc, token)!

	return true, glob_npmrc, npmrc
}

fn read_npmrc(file string) ![]string {
	d.log('reading "%s"', file)
	return read_lines(file)!
}

fn has_auth_token(npmrc []string) !bool {
	for line in npmrc {
		if line.contains('//registry.npmjs.org/:_authToken') {
			d.log_str('is authenticated')
			return true
		}
		d.log('ignoring line "%s"', line)
	}
	d.log_str('is not authenticated')
	return false
}

fn set_auth_token(file string, lines []string, token string) ! {
	d.log('creating "%s"', file)
	mut out := create(file)!
	defer {
		out.close()
	}

	d.log_str('writing new contents')
	for line in lines {
		out.writeln(line)!
	}
	if token.len > 0 {
		out.write_string('//registry.npmjs.org/:_authToken=')!
		out.writeln(token)!
	}

	out.close()
	d.log_str('file written')
}

fn get_npm_token() !string {
	return getenv_opt('NODE_AUTH_TOKEN') or {
		getenv_opt('NPM_TOKEN') or { return error('neither NODE_AUTH_TOKEN nor NPM_TOKEN found') }
	}
}
