require_relative 'json'

module Praxo
  module JsonSchema
    ValidationError = Struct.new(:path, :message, keyword_init: true)

    module_function

    def validate(schema, data)
      errors = []
      visit(schema, data, '$', errors)
      errors
    end

    def visit(schema, data, path, errors)
      return unless schema.is_a?(Hash)
      type = schema['type'].is_a?(String) ? schema['type'] : ''
      if data.nil?
        errors << ValidationError.new(path: path, message: "expected #{type}, got null") unless type.empty?
        return
      end
      case type
      when 'object' then visit_object(schema, data, path, errors)
      when 'array' then visit_array(schema, data, path, errors)
      when 'string' then visit_string(schema, data, path, errors)
      when 'number', 'integer' then visit_number(schema, type, data, path, errors)
      when 'boolean' then visit_boolean(schema, data, path, errors)
      end
    end

    def visit_object(schema, data, path, errors)
      unless data.is_a?(Hash)
        errors << ValidationError.new(path: path, message: 'expected object')
        return
      end
      Array(schema['required']).each do |name|
        next unless name.is_a?(String)
        unless data.key?(name)
          errors << ValidationError.new(path: "#{path}.#{name}", message: 'required field missing')
        end
      end
      properties = schema['properties']
      if properties.is_a?(Hash)
        properties.each do |name, child|
          visit(child, data[name], "#{path}.#{name}", errors) if data.key?(name)
        end
      end
    end

    def visit_array(schema, data, path, errors)
      unless data.is_a?(Array)
        errors << ValidationError.new(path: path, message: 'expected array')
        return
      end
      items = schema['items']
      return unless items.is_a?(Hash)
      data.each_with_index { |value, index| visit(items, value, "#{path}[#{index}]", errors) }
    end

    def visit_string(schema, data, path, errors)
      unless data.is_a?(String)
        errors << ValidationError.new(path: path, message: 'expected string')
        return
      end
      length = data.length
      min = schema['minLength'].is_a?(Numeric) ? schema['minLength'].to_i : 0
      max = schema['maxLength'].is_a?(Numeric) ? schema['maxLength'].to_i : 0
      if min.positive? && length < min
        errors << ValidationError.new(path: path, message: "min length #{min}, got #{length}")
      end
      if max.positive? && length > max
        errors << ValidationError.new(path: path, message: "max length #{max}, got #{length}")
      end
      if schema['pattern'].is_a?(String)
        begin
          regex = Regexp.new(schema['pattern'])
          unless regex.match?(data)
            errors << ValidationError.new(path: path,
              message: "pattern '#{schema['pattern']}' not matched")
          end
        rescue RegexpError
          errors << ValidationError.new(path: path,
            message: "invalid pattern '#{schema['pattern']}'")
        end
      end
      check_enum(schema, data, path, errors)
    end

    def visit_number(schema, type, data, path, errors)
      unless data.is_a?(Numeric)
        errors << ValidationError.new(path: path, message: 'expected number')
        return
      end
      if type == 'integer' && data.to_i != data
        errors << ValidationError.new(path: path, message: "expected integer, got #{data}")
        return
      end
      check_enum(schema, data, path, errors)
      if schema['minimum'].is_a?(Numeric) && schema['minimum'] != 0 && data < schema['minimum']
        errors << ValidationError.new(path: path, message: 'value below minimum')
      end
      if schema['maximum'].is_a?(Numeric) && schema['maximum'] != 0 && data > schema['maximum']
        errors << ValidationError.new(path: path, message: 'value above maximum')
      end
    end

    def visit_boolean(schema, data, path, errors)
      unless data == true || data == false
        errors << ValidationError.new(path: path, message: 'expected boolean')
        return
      end
      check_enum(schema, data, path, errors)
    end

    def check_enum(schema, data, path, errors)
      values = schema['enum']
      return unless values.is_a?(Array) && !values.empty?
      return if values.any? { |value| Json.equals(value, data) }
      errors << ValidationError.new(path: path, message: 'value not in enum')
    end
  end
end
