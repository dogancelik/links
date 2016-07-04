injectCss = (css) ->
  type = undefined
  if typeof css == 'string'
    css = css.trim()
  else
    return false
  if css.indexOf('/') == 0 or css.indexOf('http:') == 0 or css.indexOf('https:') == 0
    type = 'link'
  else
    type = 'style'
  el = document.createElement(type)
  el.type = 'text/css'
  if type == 'link'
    el.rel = 'stylesheet'
    el.href = css
  else
    el.innerHTML = css
  document.head.appendChild el
  el

getOs = ->
  platform = navigator.platform.toUpperCase()
  if platform.indexOf('MAC') > -1
    return 'mac'
  if platform.indexOf('WIN') > -1
    return 'windows'
  if platform.indexOf('LINUX') > -1
    return 'linux'
  'windows'

isYaml = (str) ->
  /\.(ya?ml)$/.test str

stripQuotes = (str) ->
  str.replace /^"(.*)"$/, '$1'

setDefaults = (links) ->
  links.map (i) ->
    if typeof i.type == 'undefined'
      i.type = 'page'
    i
