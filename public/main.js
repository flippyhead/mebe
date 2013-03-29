(function() {

  $(function() {
    $('#extra-extra').mouseover(function() {
      return $('#extra-underscore').delay(100).fadeIn(500);
    });
    $('#extra-underscore').mouseover(function() {
      return $('#extra-index').delay(100).fadeIn(500);
    });
    $('#extra-index').mouseover(function() {
      return $('#extra-tryit').delay(100).fadeIn(500);
    });
    return $('form').submit(function(e) {
      var keyword;
      e.preventDefault();
      keyword = $('input').val().trim().replace(/\s/g, '_');
      if (!keyword) return;
      return window.location = "http://mebe.co/" + keyword + ".jpg";
    });
  });

}).call(this);
