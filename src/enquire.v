import os { exists, getwd, join_path_single, read_file, real_path }
import prantlf.jany { Any }
import prantlf.json { ParseOpts, parse }

fn find_package() !(string, string) {
	return find_file('package.json')!
}

fn read_json(file string) !Any {
	dfile := d.rwd(file)
	d.log('reading file "%s"', dfile)
	text := read_file(file)!
	return parse(text, ParseOpts{})!
}

fn find_file(name string) !(string, string) {
	mut dir := getwd()
	for i := 0; i < 10; i++ {
		mut file := join_path_single(dir, name)
		mut ddir := d.rwd(dir)
		d.log('checking if "%s" exists in "%s"', name, ddir)
		if exists(file) {
			dir = real_path(dir)
			ddir = d.rwd(dir)
			d.log('"%s" found in "%s"', name, ddir)
			file = join_path_single(dir, name)
			return dir, file
		}
		dir = join_path_single(dir, '..')
	}
	return error('"${name}" not found')
}

fn unreachable() IError {
	panic('unreachable code')
}

fn get_name() !string {
	_, pkg_file := find_package()!
	pkg := read_json(pkg_file)!
	return if name := pkg.object()!['name'] {
		name.string()!
	} else {
		''
	}
}

fn get_current_version() !string {
	_, pkg_file := find_package()!
	pkg := read_json(pkg_file)!
	return if ver := pkg.object()!['version'] {
		ver.string()!
	} else {
		''
	}
}
