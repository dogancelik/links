angular
  .module 'App', ['ngRoute', 'ngStorage', 'angular-cache']

  .factory 'LinksLoader', ($http, $q, $rootScope) ->
    getData = (response) ->
      url = response.config.url
      data = null
      data = if isYaml(url) then data = jsyaml.load(response.data) else data = response.data
      # Add _url to all response data object
      data._url = url
      data

    combineObjects = (objArray) ->
      allLinks = []
      objArray.filter((obj) ->
        if ! !obj and obj instanceof Object
          if obj.hasOwnProperty('links')
            return true
        console.error 'Incorrect object:', obj
        false
        # discard everything else that doesn't have 'links' property
      ).forEach (obj) ->
        # _source for identify - base64
        links = obj.links.map((link) ->
          link._url = obj._url
          link._source = window.btoa(obj._url)
          link
        )
        allLinks = allLinks.concat(links)
        return
      objArray.push allLinks
      objArray

    getLastItem = (arr) ->
      arr.slice(-1)[0]

    {
      load: ->
        urls = $rootScope.settings.url.split('\n').filter((url) -> url.length > 0)
        promises = urls.map (url) ->
          $http.get(url).then getData, (err) ->
            console.error 'HTTP error:', err
            $q.reject err
        $q.all(promises).then(combineObjects).then getLastItem
    }

  .directive 'myTypeahead', ->
    {
      restrict: 'C'
      scope: true
      link: (scope, el, attrs) ->
        input = $(el[0])
        engine = null
        scope.$root.$watch 'loadedLinks', (nVal, oVal) ->
          if nVal != null
            engine = getEngine(scope.$root.loadedLinks)
            input.typeahead {
              hint: false
              highlight: true
              minLength: 1
            },
              name: 'links'
              source: engine
              limit: scope.$root.settings.limit
              templates: suggestion: suggestionFn
              display: 'name'
            input.bind 'typeahead:select', (e, obj) ->
              target = scope.$root.settings[if obj.type == 'page' then 'openPage' else 'openFile']
              target = stripQuotes(target)
              target = if target == 'new' then '_blank' else '_self'
              window.open obj.url, target
          input.focus()
        scope.$watch 'term', -> input.val(scope.term).trigger('input').focus()
    }

  .factory 'Settings', ($localStorage) ->
    urls = [
      '/db/db-global.yml'
      '/db/db-' + getOs() + '.yml'
    ].join('\n')
    storageDefault =
      url: urls
      openFile: 'current'
      openPage: 'new'
      cache: true
      limit: 10
    {
      reset: ->
        $localStorage.$reset storageDefault
      storage: $localStorage.$default(storageDefault)
    }

  .controller 'SettingsCtrl', ($scope, $rootScope, Settings, $http) ->
    status = ->
      $scope.status = 'Please reload page'

    $scope.reset = ->
      Settings.reset()
      status()

    $scope.clear = ->
      $http.defaults.cache.destroy()
      status()

  .controller 'TagsCtrl', ($scope, $rootScope) ->
    tags = {}
    $rootScope.loadedLinks
      .map (i) -> i.tags
      .forEach (itags) ->
        itags.forEach (tag) ->
          tags[tag] = if tags.hasOwnProperty(tag) then tags[tag] + 1 else 1

    $scope.getClass = (val) ->
      cls = 1
      if val > 10
        cls = 10
      if val > 25
        cls = 25
      if val > 50
        cls = 50
      if val > 100
        cls = 100
      'tag-' + cls

    $scope.tags = tags

  .controller 'TypeCtrl', ($scope, $routeParams, $filter) ->
    $scope.term = $filter('tagReplace')($routeParams.term)

  .controller 'ListCtrl', ($scope, $routeParams, $filter) ->
    engine = null

    triggerChange = -> $scope.change() if $scope.term.length > 0

    $scope.$root.$watch 'loadedLinks', (nVal, oVal) ->
      engine = getEngine($scope.$root.loadedLinks)
      triggerChange()

    $scope.searchResults = []

    $scope.change = -> engine.search($scope.term.trim(), (links) -> $scope.searchResults = links) if engine

    $scope.term = $filter('tagReplace')($routeParams.term)
    triggerChange()

  .filter 'tagReplace', -> (input) -> if input then input.replace(/tag:/gi, '#') else ''
  .filter 'noReferrer', -> (input) -> 'https://href.li/?' + input
  .filter 'filename', -> (input) -> input.split('/').slice(-1)[0]
  .filter 'getFaviconUrl', -> (input) -> 'https://www.google.com/s2/favicons?domain_url=' + input

  .config ($routeProvider) ->
    $routeProvider
      .when '/type/:term?', templateUrl: 'typeahead.html', controller: 'TypeCtrl'
      .when '/list/:term?', templateUrl: 'list.html', controller: 'ListCtrl'
      .when '/tags', templateUrl: 'tags.html'
      .otherwise redirectTo: '/type'

  .run ($http, $rootScope, Settings, CacheFactory, LinksLoader) ->
    $rootScope.settings = Settings.storage

    injectCss $rootScope.settings.css if $rootScope.settings.css != null

    if $rootScope.settings.cache == true
      $http.defaults.cache = CacheFactory 'defaultCache',
        maxAge: 15 * 60 * 1000
        cacheFlushInterval: 60 * 60 * 1000
        deleteOnExpire: 'aggressive'
        storageMode: 'localStorage'

    LinksLoader.load().then (links) -> $rootScope.loadedLinks = links
