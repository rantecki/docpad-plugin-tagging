# Tagging Plugin for DocPad
Extends [DocPad's](https://docpad.org) tagging features by adding tag cloud generation and automatic tag index pages.

## Install

```
npm install --save docpad-plugin-tagging
```

## Usage

### Tag Cloud

Add tag metadata to your documents as described in the [Related Plugin](https://github.com/docpad/docpad-plugin-related/).

The plugin adds the `tagCloud` object to our template-data, which includes both the count (number of occurences) and weight of the tag.  The following example iterates through `tagCloud` and generates links to the tag index pages (in *eco*):

```
<% for tag, data of @tagCloud: %>
    <a href="<%= data.url %>" data-tag-count="<%= data.count %>" data-tag-weight="<%= data.weight %>">
        <%= tag %>
    </a>
<% end %>
```

Note that in this example we've added the count and weight here as HTML5 data fields so that a client-side script can apply the desired styling.  You can of course do whatever you wish with the count or weight values, such as adding inline CSS for setting the font-size (but of course we don't do that kind of thing anymore right?)

### Index Pages

The plugin will also dynamically generate a document for each tag found with the url `tags/[tagname].html`.  The index document is created with the following metadata (by default):

```
---
layout: tags
tag: [tagname]
---
```

The plugin does not generate any content for the index pages.  You are in complete control of what is displayed on the index pages via the layout file.

For example, let's create the following file at `layouts/tags.html.eco` to display a list of all documents that have the tag in question:

```
---
layout: default
---
<h1>Pages tagged with '<%= @document.tag %>'</h1>

<ul>
<% for doc in @getCollection('documents').findAll({tags: '$in': @document.tag}).toJSON(): %>
    <li><a href="<%= doc.url %>"><%= doc.title %></a></li>
<% end %>
</ul>
```

The plugin also adds a `getTagUrl(tagname)` function to the template-data so you can easily get the URL of the index page for a particular tag.  For example, in your templates you could display a list of the document's tags as links to their index page (this time in *coffeekup* just to keep life interesting):

```
---
title: "Random document"
layout: default
tags:
 - blarky
 - snargle
 - floopy
---
h2 -> "My Tags"
ul ->
    for tag in @document.tags
        li -> a href: @getTagUrl(tag), -> tag
```

## Options

- *collectionName* : Can be used to narrow the scope of the plugin to a specific collection and therefore improve performance (defaults to 'documents').
- *indexPageLayout* : Override the name of the layout file used for the tag index pages (defaults to 'tags').
- *indexPagePath* : Override the relative output path of the tag index pages (defaults to 'tags').
- *getTagWeight* : Override the function used to generate the tag weights (see below).

### Customising the weight function

By default, the tag weights are calculated using a simple logarithmic algorithm.  If that isn't floating your proverbial boat you are free to override this function with the weight function of your choosing.  For example in your docpad config you could add:

```
plugins:
    tagging:
        getTagWeight: (count, maxCount) ->
            return count/maxCount
```

Here `count` is the number of occurences of the tag, and `maxCount` is the count of the tag with the highest number of occurrences.

## License
Licensed under the incredibly [permissive](http://en.wikipedia.org/wiki/Permissive_free_software_licence) [MIT License](http://creativecommons.org/licenses/MIT/)
<br/>Copyright &copy; 2013 [Richard Antecki](http://richard.antecki.id.au)
