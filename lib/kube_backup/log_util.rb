module KubeBackup
  module LogUtil
    extend self

    def dump(object)
      if object.is_a?(Hash)
        hash(object)
      elsif object.is_a?(Time)
        object.to_s
      #elsif object.is_a?(BigDecimal)
      #  object.to_s("F")
      elsif object.is_a?(Range) && object.first.is_a?(Time)
        middle = object.exclude_end? ? "..." : ".."
        "#{object.first.to_s}#{middle}#{object.last.to_s}"
      else
        object.inspect
      end
    end

    def hash(object)
      values = []
      object.each do |key, value|
        separator = ":"
        key_str = if key.is_a?(Symbol)
          key.to_s =~ /\s/ ? key.to_s.inspect : key.to_s
        else
          separator = " =>" unless key.is_a?(String)
          key.inspect
        end
        values << "#{key_str}#{separator} #{dump(value)}"
      end

      "{#{values.join(", ")}}"
    end
  end
end
