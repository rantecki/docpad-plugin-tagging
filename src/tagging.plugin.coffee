module.exports = (BasePlugin) ->

  _ = require('lodash')
  balUtil = require('bal-util')

  class Tagging extends BasePlugin
    name: 'tagging'

    config:
      collectionName: 'documents'
      indexPageLayout: 'tags'
      indexPagePath: 'tags'
      context: null
      getTagWeight: (count, maxCount) ->
        # apply logarithmic weight algorithm
        logmin = 0
        logmax = Math.log(maxCount)
        result = (Math.log(count) - logmin) / (logmax - logmin)
        return result

    tagCloud: {}
    tagCollection: null

    # This is to prevent/detect recursive firings of ContextualizeAfter event
    contextualizeAfterLock: false

    extendCollections: (next) ->
      @tagCollection = @docpad.getDatabase().createLiveChildCollection()
              .setQuery("isTagIndex", tag: $exists: true)

    extendTemplateData: ({templateData}) ->
      me = @
      templateData.getTagCloud = (options) ->
        return me.getTagCloud(options)
      templateData.getTagUrl = (tag,options) ->
        return me.getTagUrl(tag,options)
      @

    contextualizeAfter: ({collection, templateData}, next) ->
      if not @contextualizeAfterLock
        return @generateTags(collection, next)
      else
        next()
      @

    getTagCloud: (options) ->
      context = options?.context ? 'all'
      return @tagCloud[context].tags

    getTagUrl: (tag,options) ->
      query = options ? {}
      query.tag = tag
      doc = @tagCollection.findOne(query)
      return doc?.get('url')

    generateTags: (renderCollection, next) ->
      # Prepare
      me = @
      docpad = @docpad
      config = @config
      database = docpad.getDatabase()
      targetedDocuments = docpad.getCollection(@config.collectionName)
      
      # regenerate tag cloud
      
      docpad.log 'debug', 'tagging::generateTags: Generating tag cloud'
      
      targetedDocuments.forEach (document) =>
        # Prepare
        tags = document.get('tags') or []
        contexts = _(['all']).union([document.get('context') or null])
          .flatten()
          .compact()
          .value()
        
        for context in contexts
          @tagCloud[context] ?= {tags: {}, maxCount: 0}
          cloud = @tagCloud[context]
          
          for tag in tags
            cloud.tags[tag] ?=
              tag: tag,
              count: 0,
              url: ""
              weight: 0
            count = ++cloud.tags[tag].count
            cloud.maxCount = count if count > cloud.maxCount

      # generate tag index pages

      docpad.log 'debug', 'tagging::generateTags: Generating tag index pages'
      docs_created = 0
      newDocs = new docpad.FilesCollection()
      for own context, tagCloud of @tagCloud        
        for own tag of tagCloud.tags
          
          # check whether a document for this tag already exists in the collection
          if not @tagCollection.findOne({tag: tag, context: context})
            slug = balUtil.generateSlugSync(tag) 
            contextPath = if context=='all' then '' else context
            relativePath = _([
                contextPath,
                config.indexPagePath,
                slug + ".html"
              ]).compact().join('/')
            
            doc = @docpad.createDocument(
              slug: slug
              relativePath: relativePath
              context: context
              isDocument: true
              encoding: 'utf8'
            ,
              data: " " # NOTE: can't be empty string due to, quirk in FileModel (as of docpad v6.25)
              meta:
                layout: config.indexPageLayout
                referencesOthers: true
                tag: tag
                context: context
            )
            database.add doc
            newDocs.add doc
            docs_created++
            
            # if we're reloading (reset = false), our new document
            # will not have made it into the collection of modified
            # documents to render - so we need to add it
            if not renderCollection.findOne({tag: tag, context: context})
              renderCollection.add doc

      docpad.log 'debug', "tagging::generateTags: #{docs_created} new docs added"

      # docpad has already called load and contextualize on its documents
      # so we need to call it manually here for our new docs
      docpad.loadFiles {collection: newDocs}, (err) =>
        if err then return next(err)
        
        @contextualizeAfterLock = true
        docpad.contextualizeFiles {collection: newDocs}, (err) =>
          if err then return next(err)
        
          @contextualizeAfterLock = false
                  
          for own context, tagCloud of @tagCloud
            for own tag, item of tagCloud.tags
              item.url = @getTagUrl(tag, {context: context})
              item.weight = @config.getTagWeight(item.count, tagCloud.maxCount)
        
          next()

      @

