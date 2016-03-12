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

function suggestionFn (obj) {
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
      var urls = $rootScope.settings.url.split('\n')
        .filter(function (url) {
          return url.length > 0;
        });

      var promises = urls
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
      var engine = null;
      scope.$root.$watch('loadedLinks', function (nVal, oVal) {
        if (nVal != null) {
          engine = getEngine(scope.$root.loadedLinks);

          input.typeahead({
            hint: false,
            highlight: true,
            minLength: 1
          }, {
            name: 'links',
            source: engine,
            limit: scope.$root.settings.limit,
            templates: { suggestion: suggestionFn },
            display: 'name'
          });

          input.bind('typeahead:select', function(e, obj) {
            var target = scope.$root.settings[obj.type === 'page' ? 'openPage' : 'openFile'];
            target = stripQuotes(target);
            target = target == 'new' ? '_blank' : '_self';
            window.open(obj.url, target);
          });
        }
        input.focus();
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
    cache: true,
    limit: 10
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
.controller('TypeCtrl', function ($scope, $routeParams, $filter) {
  $scope.term = $filter('tagReplace')($routeParams.term);
})
.controller('ListCtrl', function ($scope, $routeParams, $filter) {
  var engine = null;
  $scope.$root.$watch('loadedLinks', function (nVal, oVal) {
    engine = getEngine($scope.$root.loadedLinks);
    triggerChange();
  });

  $scope.searchResults = [];
  $scope.change = function () {
    engine && engine.search($scope.term.trim(), function (links) {
      $scope.searchResults = links;
    });
  };

  function triggerChange () { if ($scope.term.length > 0) $scope.change(); }
  $scope.term = $filter('tagReplace')($routeParams.term);
  triggerChange();
})
.filter('tagReplace', function () {
  return function (input) {
    return input ? input.replace(/tag:/gi, '#') : '';
  }
})
.filter('noReferrer', function () {
  return function (input) {
    return 'https://href.li/?' + input;
  };
})
.filter('filename', function () {
  return function (input) {
    return input.split('/').slice(-1)[0];
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
    .when('/list/:term?', { templateUrl: 'list.html', controller: 'ListCtrl' })
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
