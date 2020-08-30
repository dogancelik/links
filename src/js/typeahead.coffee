setDefaults = (links) ->
  links.map (i) ->
    i.type = 'page' if typeof i.type == 'undefined'
    i

getEngine = (links) ->
  links = setDefaults(links)
  new Bloodhound
    datumTokenizer: (obj) ->
      tokens = []
      tokens = tokens
        .concat Bloodhound.tokenizers.whitespace(obj.name.replace(/[\(\)]/g, ''))
        .concat obj.tags.map((i) -> '#' + i)
        .concat ':' + obj.type
        .concat obj.url
      tokens
    queryTokenizer: Bloodhound.tokenizers.whitespace
    local: links
    identify: (obj) -> obj.name

getTypeIcon = (type) ->
  typeClass = ''
  switch type
    when 'file' then typeClass = 'fa-download'
    when 'bookmark' then typeClass = 'fa-bookmark'
    else typeClass = 'fa-external-link-square'
  typeClass

suggestionFn = (obj) ->
  tags = obj.tags.map((i) -> '#' + i).join(' ')
  """
  <div><div class="ta-obj">
    <div class="ta-row">
      <span class="name">#{obj.name}</span>
      <span class="type"><i class="fa #{getTypeIcon(obj.type)}"></i></span>
      <span class="tags">#{tags}</span>
    </div>
    <div class="ta-row">
      <span class="url">#{obj._url}</span>
    </div>
  </div></div>
  """
