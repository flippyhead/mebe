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
    'region': amazonS3.US_WEST_2

handleRequest = (req, res)->
  uri = url.parse req.url
  search = uri.pathname.replace(/^\//, '').split('.')
  keyword = search[0]
  extension = search[search.length-1]
  index = Object.keys(req.query)[0] or 0
  filename = "#{keyword}-#{index}.#{extension}"

  params =
    $format: 'json'
    Query: "'#{keyword.replace(/_/g, ' ')}'"
    Adult: "'Strict'"

  azure_options =
    host: settings.azure.host
    port: if settings.azure.ssl then 443 else 80
    path: "#{settings.azure.base_path}?#{qs.stringify params}"
    headers: {"Authorization": "Basic " +
      new Buffer("#{settings.azure.api_key}:#{settings.azure.api_key}")
        .toString "base64"}

  s3_options =
    BucketName: settings.amazon.bucket
    ObjectName: filename

  s3.GetObject s3_options, stream: yes, (error, data)->
    if error # not found or otherwise
      https.request(azure_options, (api_res)->
        str = ''
        api_res.on 'data', (chunk)->
          str += chunk
        api_res.on 'end', ->
          result = JSON.parse(str).d.results[index]
          unless result
            res.writeHead(404, 'Content-Type': 'image/jpeg')
            fs.createReadStream('public/404.jpeg').pipe res
            return

          image_url = result.Thumbnail.MediaUrl
          ext = mime.extension result.Thumbnail.ContentType
          filename = "#{keyword}-#{index}.#{ext}"

          http_get.get {url: image_url, stream: yes}, (error, image_res)->
            return console.error error if error
            length = image_res.headers['content-length']

            options =
              BucketName: settings.amazon.bucket
              ObjectName: filename
              ContentLength: length
              Body: image_res.stream

            s3.PutObject options, (err, data)->
              console.log '** error putting S3 object:', err if err

            res.writeHead 200, 'Content-Type': 'image/jpeg'
            image_res.stream.pipe res
            image_res.stream.on 'end', ->
              res.end()
            image_res.stream.on 'close', ->
              res.end()
            image_res.stream.on 'error', (error)->
              console.log '** error getting image data:', error
            image_res.stream.resume()
      ).end()
    else
      res.writeHead 200, 'Content-Type': 'image/jpeg'
      data.Stream.pipe res
      data.Stream.on 'end', ->
      res.end

connect()
  .use(connect.favicon())
  .use(connect.query())
  .use(connect.static 'public')
  .use(connect.logger 'dev')
  .use(handleRequest)
.listen(3000)