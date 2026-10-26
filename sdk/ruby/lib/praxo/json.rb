require 'json'

module Praxo
  module Json
    module_function

    def parse(text)
      JSON.parse(text)
    end

    def stringify(value)
      JSON.generate(value)
    end

    def get(node, key)
      node.is_a?(Hash) ? node[key] : nil
    end

    def has?(node, key)
      node.is_a?(Hash) && node.key?(key)
    end

    def string(node, key)
      value = get(node, key)
      value.is_a?(String) ? value : nil
    end

    def bool(node, key, fallback = false)
      value = get(node, key)
      value == true || value == false ? value : fallback
    end

    def int(node, key, fallback = 0)
      value = get(node, key)
      value.is_a?(Numeric) ? value.to_i : fallback
    end

    def array(node, key)
      value = get(node, key)
      value.is_a?(Array) ? value : []
    end

    def equals(left, right)
      left == right
    end
  end
end
