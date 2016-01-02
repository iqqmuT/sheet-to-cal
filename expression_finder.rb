#!/usr/bin/ruby

# Finds variables formatted by {{ variable }} and {{ if variable }}
# from given text.
#
class ExpressionFinder

  def find(text)
    if not text.instance_of? String
      return []
    end
    expressions = []
    text = text.clone
    while match = /{{([^}]*)}}/.match(text) do
      expression = match[1].strip()
      if expression.start_with? "if " then
        if_expression = expression.split(' ')[1]
        expressions << if_expression
      elsif expression != "end" then
        expressions << expression
      end
      text.gsub!(match[0], '')
    end
    expressions.uniq
  end

end

def test()
  finder = ExpressionFinder.new
  text = "Name: {{ name }}\n{{ if address }}Address: '{{ age }}'\n{{ end }}Age: {{ age }}\n"
  print finder.find(text)
end

#test()
