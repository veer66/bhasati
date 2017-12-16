require "nokogiri"
def plainize(s)
  node = Nokogiri::HTML::DocumentFragment.parse(s)
  node.text
end
