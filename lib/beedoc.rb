#!/usr/bin/env ruby
# encoding: UTF-8
# Script to generate HTML from text file.

require 'erb'
require 'iconv'

module Bee

  module Doc

    class XmlHandler

      # Utility method to escape special HTML characters (such as &, <, >, ' 
      # and ") with their entities. Also replace spaces before :;?! with 
      # unbreakable white space. NOTE : this method is also called to escape
      # HTML.
      # - text: text to process.
      def escape_xml(text)
        return nil if text == nil
        text = text.gsub(/&/, '&amp;').gsub(/</, '&lt;').gsub(/>/, '&gt;')
        # gsub(/'/, '&apos;').gsub(/"/, '&quot;')
        text = text.gsub(/( )+:/, '&#x00A0;:').gsub(/( )+;/, '&#x00A0;;').
          gsub(/( )+\?/, '&#x00A0;?').gsub(/( )+!/, '&#x00A0;!')
        return text
      end

    end

    # Parent class for all blocks. This is default one, that is paragraph.
    class Block < XmlHandler

      # Map that associates characters to a given block.
      @@map = {}

      # New method that behaves as a factory to instantiate appropriate 
      # constructor depending on first character of the block.
      # - document: parent document.
      # - lines: array of lines that make the block.
      # - base: base directory where lives document.
      def self.new(document, lines, base)
        caracter = lines.first[0..0]
        type = @@map[caracter] || Block
        object = type.allocate()
        object.send(:initialize, document, lines, base)
        return object
      end

      # Constructor.
      # - document: parent document.
      # - lines: array of lines that make the block.
      # - base: base directory where lives document.
      def initialize(document, lines, base)
        @document = document
        @lines = lines
        @base = base
      end

      # Convert default block (that is paragraph) to HTML.
      def to_html
        "<p>#{inline_html(escape_xml(@lines.join("\n")))}</p>"
      end

      # Convert to PDF HTML, that is HTML to generate PDF file (with no
      # stylesheet, which means that we must make frames for source code
      # and so on).
      def to_pdf
        to_html
      end

      # Convert to XML.
      def to_xml
        "<p>#{inline_xml(escape_xml(@lines.join("\n")))}</p>"
      end

      # Convert to markdown.
      def to_mark
        "#{inline_mark(@lines.join(" "))}"
      end

     # Regexp and replacements for inlines in HTML.
      INLINES_HTML = 
        [['(^|[^\\\\])\+(.*?)([^\\\\])\+', '\1<i>\2\3</i>'],
         ['(^|[^\\\\]?)\*(.*?)([^\\\\])\*', '\1<b>\2\3</b>'],
         ['(^|[^\\\\]?)_(.*?)([^\\\\])_',   '\1<u>\2\3</u>'],
         ['(^|[^\\\\]?)~(.*?)([^\\\\])~',   '\1<tt>\2\3</tt>']]
      # Regexp and replacements for inlines in XML.
      INLINES_XML = 
        [['(^|[^\\\\])\+(.*?)([^\\\\])\+', '\1<term>\2\3</term>'],
         ['(^|[^\\\\]?)\*(.*?)([^\\\\])\*', '\1<imp>\2\3</imp>'],
         ['(^|[^\\\\]?)_(.*?)([^\\\\])_',   '\1<imp>\2\3</imp>'],
         ['(^|[^\\\\]?)~(.*?)([^\\\\])~',   '\1<code>\2\3</code>']]
      # Regexp and replacements for inlines in Markdown.
      INLINES_MARK = 
        [['(^|[^\\\\]?)~(.*?)([^\\\\])~',   '\1`\2\3`'],
         ['(^|[^\\\\]?)\*(.*?)([^\\\\])\*', '\1**\2\3**'],
         ['(^|[^\\\\])\+(.*?)([^\\\\])\+', '\1*\2\3*'],
         ['(^|[^\\\\]?)_(.*?)([^\\\\])_',   '\1~~\2\3~~'],
         ]
      # Regexp for links
      LINKS_REGEXP = /(^|[^\\])\{(.*?)\}/m
      # Regexp for notes
      NOTES_REGEXP = /(^|[^\\])\[(.*?)\]/m

      # Utility method to process inlines for HTML.
      # - text: text to process.
      def inline_html(text)
        # process simple inlines
        for inline in INLINES_HTML
          text.gsub!(/#{inline[0]}/m, inline[1]) if text.match(/#{inline[0]}/m)
        end
        # process link inlines
        if text.match(LINKS_REGEXP)
          text.gsub!(LINKS_REGEXP) do |string|
            match = string.match(LINKS_REGEXP)
            before = match[1]
            body = match[2]
            after = match[3]
            parts = body.split(' ')
            if parts.length > 1
              url = parts.first
              link = parts[1..-1].join(' ')
            else
              url = body
              link = body
            end
            "#{before}<a href='#{url}'>#{link}</a>#{after}"
          end
        end
        # process note inlines
        if text.match(NOTES_REGEXP)
          text.gsub!(NOTES_REGEXP) do |string|
            match = string.match(NOTES_REGEXP)
            before = match[1]
            body = match[2]
            after = match[3]
            @document.notes << body
            index = @document.notes.length
            "#{before}<a href='#note#{index}' name='source#{index}'>"+
              "[#{index}]</a>#{after}"
          end
        end
        # process escapes (that is \x is replaced with x)
        text.gsub!(/\\(.)/, "\\1") if text.match(/\\(.)/)
        text
      end

      # Utility method to process inlines for XML.
      # - text: text to process.
      def inline_xml(text)
        # process simple inlines
        for inline in INLINES_XML
          text.gsub!(/#{inline[0]}/m, inline[1]) if text.match(/#{inline[0]}/m)
        end
        # process link inlines
        if text.match(LINKS_REGEXP)
          text.gsub!(LINKS_REGEXP) do |string|
            match = string.match(LINKS_REGEXP)
            before = match[1]
            body = match[2]
            after = match[3]
            parts = body.split(' ')
            if parts.length > 1
              url = parts.first
              link = parts[1..-1].join(' ')
            else
              url = body
              link = body
            end
            "#{before}<link url='#{url}'>#{link}</link>#{after}"
          end
        end
        # process note inlines
        if text.match(NOTES_REGEXP)
          text.gsub!(NOTES_REGEXP) do |string|
            match = string.match(NOTES_REGEXP)
            before = match[1]
            body = match[2]
            after = match[3]
            @document.notes << body
            index = @document.notes.length
            "#{before}<note>#{body}</note>#{after}"
          end
        end
        # process escapes (that is \x is replaced with x)
        text.gsub!(/\\(.)/, "\\1") if text.match(/\\(.)/)
        text
      end

      # Utility method to process inlines for Markdown.
      # - text: text to process.
      def inline_mark(text)
        # process simple inlines
        for inline in INLINES_MARK
          text.gsub!(/#{inline[0]}/m, inline[1]) if text.match(/#{inline[0]}/m)
        end
        # process note inlines
        if text.match(NOTES_REGEXP)
          text.gsub!(NOTES_REGEXP) do |string|
            match = string.match(NOTES_REGEXP)
            before = match[1]
            body = match[2]
            after = match[3]
            @document.notes << body
            index = @document.notes.length
            "#{before}#{index}[#{body}]#{after}"
          end
        end
        # process link inlines
        if text.match(LINKS_REGEXP)
          text.gsub!(LINKS_REGEXP) do |string|
            match = string.match(LINKS_REGEXP)
            before = match[1]
            body = match[2]
            after = match[3]
            parts = body.split(' ')
            if parts.length > 1
              url = parts.first
              link = parts[1..-1].join(' ')
            else
              url = body
              link = body
            end
            "#{before}[#{link}](#{url})#{after}"
          end
        end
        # process escapes (that is \x is replaced with x)
        text.gsub!(/\\(.)/, "\\1") if text.match(/\\(.)/)
        text
      end

    end

    # Comment block
    class Comment < Block

      @@map['#'] = Comment
      # accessor for lines (to extract document properties)
      attr_reader :lines

      # Convert to HTML
      def to_html
        comment = @lines.map{|line| escape_comment(line.match(/#\s*(.*)/)[1])}.
          join("\n")
        "<!--\n#{comment}\n-->"
      end

      # Convert to XML
      def to_xml
        to_html
      end

      # Convert to Markdown
      def to_mark
        @lines.map{|line| "% #{line.match(/#\s*(.*)/)[1]}"}.join("\n")
      end

      # Escape HTML comments, removing -- (wich are forbidden in comments).
      # - text: text to process.
      def escape_comment(text)
        text.gsub(/--/, '')
      end

    end

    # Source block
    class Source < Block

      @@map['$'] = Source

      # Convert to HTML.
      def to_html
        indent = @lines.first.match(/\$\s*/)[0].length
        "<pre>#{@lines.map{|line| escape_xml(line[indent..-1])}.join("\n")}</pre>"
      end

      # Convert to PDF HTML.
      def to_pdf
        indent = @lines.first.match(/\$\s*/)[0].length
        source = @lines.map{|line| escape_xml(line[indent..-1])}.join("\n")
        "<table width='100%' border='0' cellpadding='10'><tr>"+
          "<td bgcolor='#F0F0F0'><pre>#{source}</pre>"+
          "</td></tr></table><p></p>"
      end

      # Convert to XML.
      def to_xml
        indent = @lines.first.match(/\$\s*/)[0].length
        "<source>#{@lines.map{|line| escape_xml(line[indent..-1])}.join("\n")}</source>"
      end

      # Convert to Markdown.
      def to_mark
        indent = @lines.first.match(/\$\s*/)[0].length
        "```\n#{@lines.map{|line| line[indent..-1]}.join("\n")}\n```"
      end

    end

    # Reference block (image or included file).
    class Reference < Block

      @@map['@'] = Reference

      # Convert to HTML.
      def to_html
        file = @lines.first.match(/@\s*(.*)/)[1]
        ext = File.extname(file)
        if ['.png', '.gif', '.jpg'].include?(ext.downcase)
          # image
          "<center><p><img src='#{file}'></p></center>"
        else
          # other file
          source = escape_xml(File.read(File.join(@base, file)))
          "<p><pre>#{source}</pre></p>"
        end
      end

      # Convert to PDF HTML.
      def to_pdf
        file = @lines.first.match(/@\s*(.*)/)[1]
        ext = File.extname(file)
        if ['.png', '.gif', '.jpg'].include?(ext.downcase)
          # image
          "<center><p><img src='#{file}'></p></center>"
        else
          # other file
          source = escape_xml(File.read(File.join(@base, file)))
          "<table width='100%' border='0' cellpadding='10'><tr>"+
            "<td bgcolor='#F0F0F0'><pre>#{source}</pre>"+
            "</td></tr></table><p></p>"
        end
      end

      # Convert to XML.
      def to_xml
        file = @lines.first.match(/@\s*(.*)/)[1]
        ext = File.extname(file)
        if ['.png', '.gif', '.jpg'].include?(ext.downcase)
          # image
          "<figure url='#{file}'></figure>"
        else
          # other file
          source = escape_xml(File.read(File.join(@base, file)))
          "<source>#{source}</source>"
        end
      end

      # Convert to Markdown.
      def to_mark
        file = @lines.first.match(/@\s*(.*)/)[1]
        ext = File.extname(file)
        if ['.png', '.gif', '.jpg'].include?(ext.downcase)
          # image
          "![](#{file})"
        else
          # other file
          source = File.read(File.join(@base, file))
          "```\n#{source}\n```"
        end
      end

    end

    # Header block.
    class Header < Block

      @@map['!'] = Header

      # Convert to HTML.
      def to_html
        match = @lines.first.match(/(!+)\s*(.*)/)
        level = match[1].length + 1
        text = inline_html(escape_xml(match[2]))
        name = match[2].gsub(/ /, '_')
        "<a name='#{name}'><h#{level}>#{text}</h#{level}></a>"
      end

      # Convert to XML.
      def to_xml
        match = @lines.first.match(/(!+)\s*(.*)/)
        level = match[1].length
        text = inline_xml(escape_xml(match[2]))
        if level <= @document.header_level
          closure = '</sect>'*(@document.header_level - level + 1)
        else
          closure = ''
        end
        @document.header_level = level
        closure+"<sect><title>#{text}</title>"
      end

      # Convert to Markdown.
      def to_mark
        match = @lines.first.match(/(!+)\s*(.*)/)
        level = match[1].length
        text = match[2]
        @document.header_level = level
        "#{'#'*level} #{text}"
      end

    end
1
    # Unordered list block.
    class UnorderedList < Block

      @@map['-'] = UnorderedList

      # Convert to HTML.
      def to_html
        lines = []
        for line in @lines
          if line =~ /^-/
            lines << inline_html(escape_xml(line.match(/^-\s*(.*)/)[1]))
          else
            lines.last << ' '+inline_html(escape_xml(line.strip))
          end
        end
        source = "<ul>\n"
        for line in lines
          source << "<li>#{line}</li>\n"
        end
        source << "</ul>"
      end

      # Convert to XML.
      def to_xml
        lines = []
        for line in @lines
          if line =~ /^-/
            lines << inline_xml(escape_xml(line.match(/^-\s*(.*)/)[1]))
          else
            lines.last << ' '+inline_xml(escape_xml(line.strip))
          end
        end
        source = "<list>\n"
        for line in lines
          source << "<item>#{line}</item>\n"
        end
        source << "</list>"
      end

      # Convert to Markdown.
      def to_mark
        lines = []
        for line in @lines
          if line =~ /^-/
            lines << line.match(/^-\s*(.*)/)[1]
          else
            lines.last << ' '+line.strip
          end
        end
        source = ""
        for line in lines
          source << "- #{inline_mark(line)}\n"
        end
        source
      end

    end

    # Ordered list block.
    class OrderedList < Block

      @@map['*'] = OrderedList

      # Convert to HTML.
      def to_html
        lines = []
        for line in @lines
          if line =~ /^\*/
            lines << inline_html(escape_xml(line.match(/^\*\s*(.*)/)[1]))
          else
            lines.last << ' '+inline_html(escape_xml(line.strip))
          end
        end
        source = "<ol>\n"
        for line in lines
          source << "<li>#{line}</li>\n"
        end
        source << "</ol>"
      end

      # Convert to XML.
      def to_xml
        lines = []
        for line in @lines
          if line =~ /^\*/
            lines << inline_xml(escape_xml(line.match(/^\*\s*(.*)/)[1]))
          else
            lines.last << ' '+inline_xml(escape_xml(line.strip))
          end
        end
        source = "<enum>\n"
        for line in lines
          source << "<item>#{line}</item>\n"
        end
        source << "</enum>"
      end

      # Convert to Markdown.
      def to_mark
        lines = []
        index = 1
        for line in @lines
          if line =~ /^\*/
            lines << "#{index}. #{inline_mark(line.match(/^\*\s*(.*)/)[1])}"
          else
            lines.last << " #{inline_mark(line.strip)}"
          end
          index += 1
        end
        lines.join("\n")
      end

    end

    # Document, made of a list of blocks.
    class Document < XmlHandler

      PDF_ENCODING = 'ISO-8859-1'

      attr_reader :notes
      attr_accessor :header_level

      # HTML document template
      HTML_TEMPLATE = <<'EOF'
<html>
<head>
% encoding = @properties['encoding'] || 'UTF-8'
% if encoding
<meta http-equiv='Content-Type' content='text/html; charset=<%= encoding %>'>
% end
% title = @properties['title']
% if title
<title><%= title %></title>
% end
% for stylesheet in @stylesheets
%   if @embed
<style type='text/css' media='screen'>
<!--
<%= File.read(stylesheet) %>
-->
</style>
%   else
<link rel='stylesheet' type='text/css' href='<%= stylesheet %>'>
%   end
% end
</head>
<body marginwidth="10" marginheight="10" bgcolor="#213449">
<table class="page" width="700" height="100%" align="center">
<tr class="page" valign="top">
<td class="page">
% if title
<center><h1><%= title %></h1></center>
% end
% author = @properties['author']
% if author
<center>
<i>
<font size="-2">
&copy; <%= author %>
% email = @properties['email']
% if email
(<a href="mailto:<%= email %>"><%= email %></a>)
% end
</font>
</i>
</center>
<br>
<br>
% end
% for block in @blocks
<%= block.to_html %>
% end
% if @notes.length > 0
<hr noshade='true' size='1'>
<table class="note" width="100%">
%   @notes.each_with_index do |note, index|
<tr class="note">
<td class="note" align="left" valign="top">
<a href='#source<%= index+1 %>' name='note<%= index+1 %>'>[<%= index+1 %>]</a>
</td>
<td class="note" align="left" valign="top" width="100%">
<%= note %>
</td>
</tr>
%   end
</table>
% end
</td></tr></table>
</body>
</html>
EOF
      # PDF HTML document template
      PDF_TEMPLATE = <<'EOF'
<html>
<head>
<meta http-equiv='Content-Type' content='text/html; charset=ISO-8859-1'>
% title = @properties['title']
% if title
<title><%= title %></title>
% end
</head>
<body>
% if title
<center><h1><%= title %></h1></center>
% end
% author = @properties['author']
% if author
<center>
<i>
<font size="-2">
&copy; <%= author %>
% email = @properties['email']
% if email
(<a href="mailto:<%= email %>"><%= email %></a>)
% end
</font>
</i>
</center>
<br>
<br>
% end
% for block in @blocks
%   html = block.to_pdf
<%= html %>
% end
% if @notes.length > 0
<hr noshade='true' size='1'>
<table class="note" width="100%">
%   @notes.each_with_index do |note, index|
<tr class="note">
<td class="note" align="left" valign="top">
<a href='#source<%= index+1 %>' name='note<%= index+1 %>'>[<%= index+1 %>]</a>
</td>
<td class="note" align="left" valign="top" width="100%">
<%= note %>
</td>
</tr>
%   end
</table>
% end
</body>
</html>
EOF
      # XML document template
      XML_TEMPLATE = <<'EOF'
% encoding = @properties['encoding'] || 'UTF-8'
<?xml version="1.0" encoding="<%= encoding %>"?>
<!DOCTYPE article PUBLIC "-//CAFEBABE//DTD article 1.0//EN"
                         "../dtd/article.dtd">

% id = @properties['title'].gsub(/ /, '_')
% title = @properties['title']
% author = @properties['author']
% email = @properties['email']
% date = @properties['date']
% lang = 'fr'
<article id="<%= id %>"
         author="<%= author %>" 
         email="<%= email %>"
         date="<%= date %>"
         lang="<%= lang %>">

 <title><%= title %></title>

 <text>

% for block in @blocks
%   xml = block.to_xml
<%= xml %>
% end
% if @header_level > 0
%   @header_level.times do
</sect>
%   end
% end

 </text>

</article>
EOF

      # Blog entry template
      BLOG_TEMPLATE = <<'EOF'
% encoding = @properties['encoding'] || 'UTF-8'
<?xml version="1.0" encoding="<%= encoding %>"?>
<!DOCTYPE weblog PUBLIC "-//CAFEBABE//DTD weblog 1.0//EN"
                        "../dtd/weblog.dtd">

% id = @properties['title'].gsub(/\W/, '_')
% date = @properties['date']
% title = @properties['title']
<weblog id="<%= id %>"
        date="<%= date %>">

 <title><%= title %></title>

% for block in @blocks
%   xml = block.to_xml
<%= xml %>
% end
% if @header_level > 0
%   @header_level.times do
</sect>
%   end
% end

</weblog>
EOF

      # Markdown document template
      MARK_TEMPLATE = <<'EOF'
% encoding = @properties['encoding'] || 'UTF-8'
% id = @properties['title'].gsub(/ /, '_')
% title = @properties['title']
% author = @properties['author']
% email = @properties['email']
% date = @properties['date']
% lang = 'fr'
% for block in @blocks
%   text = block.to_mark
<%= text %>

% end
EOF

      # Constructor.
      # - text: text source.
      # - stylesheets: array of stylesheet file names.
      # - base: document base directory.
      def initialize(text, base, format, stylesheets=nil, embed=true)
        @notes = []
        @base = base
        @header_level = 0
        lines = text.split("\n")
        blocks = []
        block = []
        for line in lines
          if line.strip.empty?
            if block.size > 0
              blocks << block
              block = []
            end
          else
            block << line
          end
        end
        if block.size > 0
          blocks << block
        end
        @blocks = []
        for block in blocks
          @blocks << Block.new(self, block, @base)
        end
        # parse first block to extract document properties
        @properties = {}
        if @blocks.first.kind_of? Comment
          for line in @blocks.first.lines
            text = line.match(/#\s*(.*)/)[1]
            parts = text.split(':')
            name = parts[0].strip
            value = parts[1..-1].join(':').strip
            if ['title'].include?(name) and [:xml, :html, :blog].include?(format)
                value = escape_xml(value)
            end
            @properties[name] = value
          end
        end
        # set stylesheets
        @stylesheets = stylesheets || []
        # tell if we should embed stylesheets
        @embed = embed
      end

      # Convert to HTML.
      def to_html
        template = ERB.new(HTML_TEMPLATE, 0, '%')
        template.result binding
      end

      # Convert to PDF HTML.
      def to_pdf
        template = ERB.new(PDF_TEMPLATE, 0, '%')
        Iconv.conv(PDF_ENCODING, @properties['encoding'],
                   template.result(binding))
      end

      # Convert to XML.
      def to_xml
        template = ERB.new(XML_TEMPLATE, 0, '%')
        template.result binding
      end

      # Convert to blog.
      def to_blog
        template = ERB.new(BLOG_TEMPLATE, 0, '%')
        template.result binding
      end

      # Convert to Markdown.
      def to_mark
        template = ERB.new(MARK_TEMPLATE, 0, '%')
        template.result binding
      end

    end

  end

end
