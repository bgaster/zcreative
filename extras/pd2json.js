// my-parser.mjs
import { readFileSync } from 'fs'
import parse from '@webpd/pd-parser'

// Read a pd file
const somePdFile = readFileSync(process.argv[2], { encoding: 'utf8' })

// Parse the pd file text to a javascript object you can directly work with
const result = parse(somePdFile)

// Print the result of the parsing operation
console.log(JSON.stringify(result))

// Print the JS representation of the pd file
