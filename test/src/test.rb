#!/usr/bin/env ruby

class Block

  @@map = {}

  def self.new(lines)
    caracter = lines.first[0..0]
    type = @@map[caracter] || Block
    object = type.allocate()
    object.send(:initialize, lines)
    return object
  end

  def initialize(lines)
    @lines = lines
  end

  def to_html
    "<p>#{@lines.join(" ")}</p>"
  end

end
