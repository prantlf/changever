module main

import os { chdir, getwd }

fn test_find_file_curdir() {
	cwd := getwd()
	dir, name := find_file('package.json')!
	assert dir == cwd
	assert name == '${cwd}${os.path_separator}package.json'
}

fn test_find_file_subdir() {
	cwd := getwd()
	chdir('src')!
	dir, name := find_file('package.json')!
	chdir('..')!
	assert dir == cwd
	assert name == '${cwd}${os.path_separator}package.json'
}

fn test_find_file_miss() {
	find_file('dummy') or { return }
	assert false
}

fn test_find_package() {
	cwd := getwd()
	dir, name := find_package()!
	assert dir == cwd
	assert name == '${cwd}${os.path_separator}package.json'
}

fn test_read_json() {
	any := read_json('package.json')!
	assert any.get('name')!.string()! == 'changever'
}

fn test_get_name() {
	name := get_name()!
	assert name == 'changever'
}

fn test_get_current_version() {
	ver := get_current_version()!
	assert ver.len > 0
}

fn test_get_repo_url() {
	url, found := get_repo_url('.git')!
	assert url == 'git@github.com:prantlf/changever.git'
		|| url == 'https://github.com/prantlf/changever'
	assert found == true
}
