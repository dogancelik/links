angular
  .module 'App', ['ngRoute', 'ngStorage', 'angular-cache']

  .constant 'sourcesUrl', 'https://api.github.com/repos/links-js/db/contents/'

  .filter 'tagReplace', -> (input) -> if input then input.replace(/tag:/gi, '#') else ''
  .filter 'noReferrer', -> (input) -> 'https://href.li/?' + input
  .filter 'filename', -> (input) -> input.split('/').slice(-1)[0]
  .filter 'getFaviconUrl', -> (input) -> 'https://www.google.com/s2/favicons?domain_url=' + input
  .filter 'getLastItem', -> (arr) -> arr.slice(-1)[0]
  .filter 'hasYamlOrJson', -> (obj) -> isYamlOrJson(obj.name)
  .filter 'getIconForOs', -> getIconForOs

  .factory 'LinksLoader', ($http, $q, $rootScope, $filter) ->
    getData = (response) ->
      url = response.config.url
      data = null
      data = if isYaml(url) then data = jsyaml.load(response.data) else data = response.data
      # Add _url to all response data object
      data._url = url
      data

    getObjWithLinks = (obj) ->
      if Boolean(obj) and (obj instanceof Object)
        if obj.hasOwnProperty 'links'
          return true
      console.error 'Incorrect object:', obj
      return false

    reduceAllObj = (prevArr, curObj) ->
      # _source for identify - base64
      links = curObj.links.map (link) ->
        link._url = curObj._url
        link._source = window.btoa(curObj._url)
        link
      prevArr.concat(links)

    combineObjects = (objArray) ->
      # discard everything else that doesn't have 'links' property then combine all files
      objArray.push objArray.filter(getObjWithLinks).reduce(reduceAllObj, [])
      objArray

    {
      load: ->
        urls = $rootScope.settings.url.split('\n').filter((url) -> url.length > 0)
        promises = urls.map (url) ->
          $http.get(url).then getData, (err) ->
            console.error 'HTTP error:', err
            $q.reject err
        $q.all(promises).then(combineObjects).then $filter('getLastItem')
    }

  .directive 'myTypeahead', ->
    {
      restrict: 'C'
      scope: true
      link: (scope, el, attrs) ->
        options =
          hint: false
          highlight: true
          minLength: 1
        dataset =
          name: 'links'
          source: null
          limit: scope.$root.settings.limit
          templates: suggestion: suggestionFn
          display: 'name'
        input = $(el[0])
        engine = null
        scope.$root.$watch 'loadedLinks', (nVal, oVal) ->
          if nVal != null
            dataset.source = getEngine(scope.$root.loadedLinks)
            input.typeahead options, dataset
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
      reset: -> $localStorage.$reset storageDefault
      storage: $localStorage.$default(storageDefault)
    }

  .controller 'SettingsCtrl', ($scope, $rootScope, Settings, $http, sourcesUrl, $filter) ->
    status = -> $scope.status = 'Please reload page'

    $http.get(sourcesUrl).then (res) ->
      $scope.sources = res.data.filter $filter('hasYamlOrJson')

    $scope.addSource = (source) ->
      $rootScope.settings.url = splitThenAdd($rootScope.settings.url, "/db/#{source.path}")

    $scope.style = (name) ->
      $rootScope.settings.css = "/styles/#{name}.css"
      status()

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

    $scope.getClass = getTagClass
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

    LinksLoader.load().then (links) ->
      console.log 'Links are loaded:', links.length
      $rootScope.loadedLinks = links
