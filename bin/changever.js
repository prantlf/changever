#!/usr/bin/env node

import { runAndReplaceLink, reportError } from 'link-bin-executable'
import { dirname } from 'path'
import { fileURLToPath } from 'url'

const __dirname = dirname(fileURLToPath(import.meta.url))

try {
  await runAndReplaceLink({ name: 'changever', scriptDirectory: __dirname })
} catch (err) {
  reportError(err)
}
