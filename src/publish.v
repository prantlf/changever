import net.http { Request }
import os { getenv_opt, join_path_single, read_lines }
import prantlf.jany { Any }
import prantlf.json { StringifyOpts, stringify }
import prantlf.osutil { ExecuteOpts, execute, execute_opt }
import prantlf.pcre { NoMatch, pcre_compile }
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
		m.group_text(line, 1) or { return unreachable() }
	} else {
		return error('unexpected output of newchanges: "${line}"')
	}

	return ver, log
}

fn do_publish(ver string, log string, opts &Opts) ! {
	publish_package(ver, opts)!

	repo_path, gh_token := if opts.release {
		path := get_repo_path()!
		token := get_gh_token(opts.gh_token)!
		if was_released(path, ver, token)! {
			msg := 'version ${ver} has been already released'
			if opts.failure {
				return error(msg)
			}
			println(msg)
			return
		}
		path, token
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
				post_release(repo_path, ver, log, gh_token)!
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
		if !opts.dry_run {
			extra_args := if opts.verbose { ' -v' } else { '' }
			out := execute('npm publish --access public${extra_args}')!
			d.log_str(out)
			eprintln('')
		}
		println('published version ${ver}${mode}')
	}
}

fn was_released(repo_path string, ver string, token string) !bool {
	url := 'https://api.github.com/repos/${repo_path}/releases/tags/v${ver}'
	d.log('getting "%s"', url)
	mut req := Request{
		method: .get
		url: url
	}
	req.add_header(.accept, 'application/vnd.github+json')
	req.add_header(.authorization, 'Bearer ${token}')
	req.add_custom_header('X-GitHub-Api-Version', '2022-11-28')!
	res := req.do()!
	d.log('received "%s"', res.body)
	if res.status_code == 200 {
		return true
	} else if res.status_code == 404 {
		return false
	}
	return error('${res.status_code}: ${res.status_msg}')
}

fn post_release(repo_path string, version string, log string, token string) ! {
	url := 'https://api.github.com/repos/${repo_path}/releases'
	body := stringify(Any(log), StringifyOpts{})
	data := '{"tag_name":"v${version}","name":"${version}","body":${body}}'
	d.log('posting "%s" to "%s"', data, url)
	mut req := Request{
		method: .post
		url: url
		data: data
	}
	req.add_header(.accept, 'application/vnd.github+json')
	req.add_header(.authorization, 'Bearer ${token}')
	req.add_header(.content_type, 'application/json')
	req.add_custom_header('X-GitHub-Api-Version', '2022-11-28')!
	res := req.do()!
	if res.status_code != 201 {
		return error('${res.status_code}: ${res.status_msg}')
	}
	d.log('received "%s"', res.body)
}

fn get_repo_path() !string {
	_, git_path := find_file('.git') or { return error('missing ".git" directory') }

	mut url, found := get_repo_url(git_path)!
	if !found {
		return error('url in ".git/config" not detected')
	}

	if url.starts_with('git@') && url.ends_with('.git') {
		url = url[..url.len - 4]
	}
	re_name := pcre_compile(r'^.+github\.com[:/]([^/]+/(?:.+))', 0) or { panic(err) }
	m := re_name.exec(url, 0) or {
		return if err is NoMatch {
			error('unsupported git url "${url}"')
		} else {
			err
		}
	}
	path := m.group_text(url, 1) or { return unreachable() }

	d.log('git repo "%s" detected', path)
	return path
}

fn get_repo_url(path string) !(string, bool) {
	file := join_path_single(path, 'config')
	dfile := d.rwd(file)
	d.log('reading file "%s"', dfile)
	lines := read_lines(file)!

	mut re_url := pcre_compile(r'\s*url\s*=\s*(.+)$', 0) or { panic(err) }
	for line in lines {
		d.log('looking for url in "%s"', line)
		if m := re_url.exec(line, 0) {
			url := m.group_text(line, 1) or { return unreachable() }
			d.log('url "%s" found', url)
			return url, true
		}
	}

	d.log_str('no url found')
	return '', false
}

fn get_gh_token(def_token string) !string {
	return getenv_opt('GITHUB_TOKEN') or {
		getenv_opt('GH_TOKEN') or {
			return if def_token.len > 0 {
				def_token
			} else {
				error('github token provided by neither GITHUB_TOKEN nor GH_TOKEN')
			}
		}
	}
}
