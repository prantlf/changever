import { access } from 'fs/promises'
import { dirname, join } from 'path'
import { fileURLToPath } from 'url'
import grab from 'grab-github-release'
import { installLink } from 'link-bin-executable'

const exists = file => access(file).then(() => true, () => false)

const __dirname = dirname(fileURLToPath(import.meta.url))

try {
  // use a locally produced executable during the build, or download it
  let executable
  executable = join(__dirname, 'changever')
  if (process.platform === 'win32') executable += '.exe'
  if (!await exists(executable)) {
    let version
    ({ executable, version } = await grab({
      repository: 'prantlf/changever',
      targetDirectory: __dirname,
      unpackExecutable: true
    }))
    console.log('downloaded and unpacked "%s" version %s', executable, version)
  }

  await installLink({
    linkNames: ['changever'],
    executable,
    packageDirectory: __dirname
  })
} catch (err) {
  console.error(err)
  process.exitCode = 1
}
