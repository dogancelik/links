function getOs() {
  var platform = navigator.platform.toUpperCase();
  if (platform.indexOf('MAC') > -1) return 'mac';
  if (platform.indexOf('WIN') > -1) return 'windows';
  if (platform.indexOf('LINUX') > -1) return 'linux';
  return 'windows';
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
      return obj.name;
    }
  });
}

function startTypeahead (input, links) {
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

        return '<div><div class="ta-obj">' +
          '<div class="ta-row">' +
            '<span class="name">' + obj.name + '</span>' +
            '<span class="type"><i class="fa ' + (obj.type === 'file' ? 'fa-download' : 'fa-external-link-square') + '"></i></span>' +
            '<span class="tags">' + tags + '</span>' +
          '</div>' +
          '<div class="ta-row">' +
            '<span class="url">' + obj._url + '</span>' +
          '</div>' +
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
.module('App', ['ngRoute', 'ngStorage', 'angular-cache'])
.factory('LinksLoader', function ($http, $q, $rootScope) {
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

  function combineObjects (objArray) {
    var allLinks = [];
    objArray.filter(function (obj) {
      if (!!obj && obj instanceof Object) {
        if (obj.hasOwnProperty('links')) {
          return true;
        }
      }
      console.error('Incorrect object:', obj);
      return false; // discard everything else that doesn't have 'links' property
    }).forEach(function (obj) {
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

  function getLastItem (arr) {
    return arr.slice(-1)[0];
  }

  return {
    load: function () {
      var urls = $rootScope.settings.url.split('\n');
      var promises = urls
        .filter(function (url) {
          return url.length > 0;
        })
        .map(function (url) {
          return $http
            .get(url)
            .then(getData, function (err) {
              console.error('HTTP error:', err);
              return $q.reject(err);
        });
      });

      return $q
        .all(promises)
        .then(combineObjects)
        .then(getLastItem);
    }
  };
})
.directive('myTypeahead', function () {
  return {
    restrict: 'C',
    scope: true,
    link: function (scope, el, attrs) {
      var input = $(el[0]);
      scope.$root.$watch('loadedLinks', function (nVal, oVal) {
        nVal && startTypeahead(input, scope.$root.loadedLinks); // if nVal is not null, start Typeahead
      });
      scope.$watch('term', function () {
        input.val(scope.term).trigger('input').focus();
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
.controller('TagsCtrl', function ($scope, $rootScope) {
  var tags = {};

  $rootScope.loadedLinks
    .map(function (i) { return i.tags; })
    .forEach(function (itags) {
      itags.forEach(function (tag) {
        tags[tag] = tags.hasOwnProperty(tag) ? tags[tag] + 1 : 1;
      });
    });

  $scope.getClass = function (val) {
    var cls = 1;
    if (val > 10) cls = 10;
    if (val > 25) cls = 25;
    if (val > 50) cls = 50;
    if (val > 100) cls = 100;
    return 'tag-' + cls;
  }

  $scope.tags = tags;
})
.controller('TypeCtrl', function ($scope, $routeParams) {
  var term = $routeParams.term ? $routeParams.term.replace(/tag:/gi, '#') : '';
  $scope.term = term;
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
.config(function ($routeProvider) {
  $routeProvider
    .when('/type/:term?', { templateUrl: 'typeahead.html', controller: 'TypeCtrl' })
    .when('/list/:term?', { templateUrl: 'list.html', controller: 'TypeCtrl' })
    .when('/tags', { templateUrl: 'tags.html' })
    .otherwise({ redirectTo: '/type' });
})
.run(function ($http, $rootScope, Settings, CacheFactory, LinksLoader) {
  $rootScope.settings = Settings.storage;

  if ($rootScope.settings.cache === true) {
    $http.defaults.cache = CacheFactory('defaultCache', {
      maxAge: 15 * 60 * 1000,
      cacheFlushInterval: 60 * 60 * 1000,
      deleteOnExpire: 'aggressive',
      storageMode: 'localStorage'
    });
  }

  LinksLoader.load().then(function (links) {
    $rootScope.loadedLinks = links;
  });
});
