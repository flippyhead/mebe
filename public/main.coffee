$ ()->
  $('#extra-extra').mouseover ->
    $('#extra-underscore').delay(100).fadeIn 500
  $('#extra-underscore').mouseover ->
    $('#extra-index').delay(100).fadeIn 500
  $('#extra-index').mouseover ->
    $('#extra-tryit').delay(100).fadeIn 500

  $('form').submit (e)->
    e.preventDefault()
    keyword = $('input').val().trim().replace(/\s/g, '_')
    return unless keyword
    window.location = "http://mebe.co/#{keyword}.jpg"