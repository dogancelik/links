function getOs() {
  var platform = navigator.platform.toUpperCase();
  switch (platform) {
    case 'MAC':
      return 'mac';
      break;
    case 'WIN':
      return 'windows';
      break;
    case 'LINUX':
      return 'linux';
      break;
    default:
      return 'windows';
      break;
  }
}

function isYaml (str) {
  return /\.(ya?ml)$/.test(str);
}

function stripQuotes (str) {
  return str.replace(/^"(.*)"$/, '$1');
}

function setDefaults (links) {
  return links.map(function (i) {
    if (typeof i.type === 'undefined') {
      i.type = 'page';
    }
    return i;
  });
}

function getEngine (links) {
  links = setDefaults(links);

  return new Bloodhound({
    datumTokenizer: function (obj) {
      var tokens = [];
      tokens = tokens
        .concat(Bloodhound.tokenizers.whitespace(obj.name))
        .concat(obj.tags.map(function(i) { return '#' + i; }))
        .concat(obj.url);
      return tokens;
    },
    queryTokenizer: Bloodhound.tokenizers.whitespace,
    local: links,
    identify: function (obj) {
      return obj._source + '/' + obj.tags.join('/') + '/' + obj.name;
    }
  });
}

function startTypeahead (links) {
  var input = $('#typeahead');

  links = getEngine(links);

  input.typeahead({
    hint: false,
    highlight: true,
    minLength: 1
  }, {
    name: 'links',
    source: links,
    limit: 10,
    templates: {
      suggestion: function (obj) {
        tags = obj.tags.map(function (i) { return '#' + i; }).join(' ');

        return '<div><div class="obj">' +
          '<span class="name">' + obj.name + '</span>' +
          '<br><span class="url">' + obj._url + '</span>' +
          '<span class="tags">' + tags + '</span>' +
          '</div></div>';
      }
    },
    display: 'name'
  });

  input.bind('typeahead:select', function(e, obj) {
    var target = target = localStorage.getItem('ngStorage-' + (obj.type === 'page' ? 'openPage' : 'openFile'));
    target = stripQuotes(target);
    target = target == 'new' ? '_blank' : '_self';
    window.open(obj.url, target);
  });
}

angular
.module('App', ['ngStorage', 'angular-cache'])
.factory('Typeahead', function ($http, $rootScope, $q) {
  function getData (response) {
    var url = response.config.url;
    var data = null;
    if (isYaml(url)) {
      data = jsyaml.load(response.data);
    } else {
      data = response.data;
    }
    // Add _url to all response data object
    data._url = url;
    return data;
  }

  function mapResponses (responses) {
    return responses.map(function(response) {
      return getData(response);
    });
  }

  function combineObjects (objArray) {
    var allLinks = [];
    objArray.forEach(function (obj) {
      // _source for identify - base64
      var links = obj.links.map(function (link) {
        link._url = obj._url;
        link._source = window.btoa(obj._url)
        return link;
      });
      allLinks = allLinks.concat(links);
    });
    objArray.push(allLinks);
    return objArray;
  }

  return {
    load: function () {
      var urls = $rootScope.settings.url.split('\n');
      var promises = urls.map(function (url) { return $http.get(url); });

      $q
        .all(promises)
        .then(mapResponses)
        .then(combineObjects)
        .then(function (arr) {
          var allLinks = arr.slice(-1)[0];
          startTypeahead(allLinks);
        });
    }
  };
})
.factory('Settings', function ($localStorage) {
  var urls = [
    '/db/db-global.yml',
    '/db/db-' + getOs() + '.yml'
  ].join('\n');

  var storageDefault = {
    url: urls,
    openFile: 'current',
    openPage: 'new',
    cache: true
  };

  return {
    reset: function () { return $localStorage.$reset(storageDefault); },
    storage: $localStorage.$default(storageDefault)
  };
})
.controller('SettingsCtrl', function ($scope, $rootScope, Settings) {
  $scope.reset = function () {
    Settings.reset();
  };
})
.filter('noReferrer', function () {
  return function (input) {
    return 'https://href.li/?' + input;
  };
})
.filter('getFaviconUrl', function () {
  return function (input) {
    return 'https://www.google.com/s2/favicons?domain_url=' + input;
  };
})
.run(function ($http, $rootScope, Settings, Typeahead, CacheFactory) {
  $rootScope.settings = Settings.storage;

  if ($rootScope.settings.cache === true) {
    $http.defaults.cache = CacheFactory('defaultCache', {
      maxAge: 15 * 60 * 1000,
      cacheFlushInterval: 60 * 60 * 1000,
      deleteOnExpire: 'aggressive',
      storageMode: 'localStorage'
    });
  }

  Typeahead.load();
});