{BAD_REQUEST, UNAUTHORIZED} = require 'http-status-codes'
prometheusMetrics = require 'express-prom-bundle'
{spawn} = require 'child-process-promise'
status = require 'express-status-monitor'
promisePipe = require 'promisepipe'
bodyParser = require 'body-parser'
tmpWrite = require 'temp-write'
tmpFile = require 'tempfile'
parallel = require 'bluebird'
express = require 'express'
log = require 'morgan'
_ = require 'lodash'
fs = require 'fs'
app = express()

app.use status()
app.use prometheusMetrics()
app.use log('combined')
app.use '/', express.static(__dirname + '/documentation')

app.post '/', bodyParser.json(), (req, res) ->
  if req.body.token != process.env.API_TOKEN
    return res.status(UNAUTHORIZED).send 'wrong token'

  decode = (base64) ->
    Buffer.from(base64, 'base64').toString 'utf8' if base64?

  decodeWrite = _.flow(decode, _.partialRight tmpWrite, '.html')

  # compile options to arguments
  argumentize = (options) ->
    return [] unless options?
    _.flatMap options, (val, key) -> ['--' + key, val]

  # async parallel file creations
  parallel.join tmpFile('.pdf'),
  decodeWrite(req.body.footer),
  decodeWrite(req.body.contents),
  (output, footer, content) ->
    # combine arguments and call pdf compiler using shell
    # injection save function 'spawn' goo.gl/zspCaC
    spawn 'wkhtmltopdf', (argumentize(req.body.options)
    .concat(['--footer-html', footer], [content, output]))
    .then ->
      res.setHeader 'Content-type', 'application/pdf'
      promisePipe fs.createReadStream(output), res
    .catch ->
      res.status(BAD_REQUEST).send 'invalid arguments'

app.listen process.env.PORT or 5555
module.exports = app