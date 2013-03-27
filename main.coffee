# main
http = require 'http'
https = require 'https'
http_get = require 'http-get'
url = require 'url'
qs = require 'querystring'
fs = require 'fs'
amazonS3 = require 'awssum-amazon-s3'
mime = require 'mime'
connect = require 'connect'
settings = require './settings'

mime.define 'image/jpg': ['jpeg']

s3 = new amazonS3.S3
    'accessKeyId': settings.amazon.access_key_id
    'secretAccessKey': settings.amazon.secret_access_key
    'region': amazonS3.US_EAST_1

connect()
  .use(connect.favicon())
  .use(connect.query())
  .use(connect.static(settings.cache.path, maxAge: 9999999, redirect: no))
  .use(connect.static('public'))
  .use(connect.logger('dev'))
  .use (req, res)->
    uri = url.parse(req.url)
    search = uri.pathname.replace(/^\//, '').split('.')
    keyword = search[0]
    extension = search[search.length-1]

    params =
      $format: 'json'
      Query: "'#{keyword.replace(/_/g, ' ')}'"
      Adult: "'Strict'"

    path = "#{settings.azure.base_path}?#{qs.stringify params}"
    auth = "Basic " +
      new Buffer("#{settings.azure.api_key}:#{settings.azure.api_key}")
        .toString "base64"

    options =
      host: settings.azure.host
      port: if settings.azure.ssl then 443 else 80
      path: path
      headers: {"Authorization": auth}

    https.request(options, (api_res)->
      str = ''
      api_res.on 'data', (chunk)->
        str += chunk
      api_res.on 'end', ->
        result = JSON.parse(str).d.results[0]
        unless result
          res.writeHead(404, 'Content-Type': 'image/jpeg')
          fs.createReadStream('public/404.jpeg').pipe res
          return

        image_url = result.Thumbnail.MediaUrl
        ext = mime.extension result.Thumbnail.ContentType
        filename = "#{keyword}.#{ext}"
        console.log 'api result', image_url

        http_get.get image_url, "./#{settings.cache.path}/#{filename}", (error, result)->
          if error
            console.error(error)
          else
            res.writeHead 302, Location: '/' + filename
            res.end()
    ).end()
 .listen(3000)