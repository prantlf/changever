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
	mode := if opts.dry_run {
		' (dry-run)'
	} else {
		''
	}

	if opts.yes || confirm('publish version ${ver}${mode}')! {
		mut extra_args := if opts.verbose { ' -v' } else { '' }
		if opts.dry_run {
			extra_args += ' --dry-run'
		}
		out := execute('npm publish --access public${extra_args}')!
		// d.log_str(out)
		// eprintln('')
		// println('published version ${ver}${mode}')
		println(out)
	}
}
