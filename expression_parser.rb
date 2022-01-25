#!/usr/bin/ruby

# Parses given string and replaces {{ variable }} expressions with
# given variable values.
#
# Supports if keyword:
# Begin {{ if variable }} Then show {{ variable }} {{ end }} End
#
# If variable exists with value "foo":
# Begin Then show foo End
#
# Else:
# Begin  End
class ExpressionParser

  def initialize(vars)
    @vars = vars
  end

  def parse(text, drop=false)
    if not text.instance_of? String
      return text
    end
    text = text.clone

    while match = /{{([^}]*)}}/.match(text) do
      expression = match[1].strip()
      if expression.start_with? "if " then
        new_text = text[match.end(0)..-1]
        # expression "if var_name" is interpreted false when
        # var_name does not exist or it has empty value
        var_name = expression.split(' ')[1]
        drop = !(@vars.key? var_name and @vars[var_name] != nil and @vars[var_name].length > 0)
        text = text[0..match.begin(0)-1] + parse(new_text, drop)

      elsif expression == "end" then
        text.sub!('end', '')
        if drop then
          return text[match.end(0)-3..-1]
        else
          return text
        end

      else
        value = if @vars.key? expression then @vars[expression] else "" end
        if value == nil then
          value = ''
        end
        text.gsub!(match[0], value)
      end
    end
    text
  end

end

def test()
  vars = {}
  vars["name"] = "John Doé"
  vars["address"] = "Street 1 City"
  vars["age"] = ""
  parser = ExpressionParser.new(vars)
  text = "Name: {{ name }}\n{{ if address }}Address: '{{ address }}'\n{{ end }}Age: {{ age }}\n"
  print parser.parse(text)
end

#test()
