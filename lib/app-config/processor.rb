module AppConfig
  module Processor
    def serialize(data, fmt)
      fmt = fmt.to_sym
      raise AppConfig::InvalidType unless AppConfig::FORMATS.include?(fmt)
      case fmt
      when :array, :hash
        YAML.dump(data)
      when :boolean
        data ? 'true' : 'false'
      else
        data
      end
    end

    def deserialize(data, fmt)
      fmt = fmt.to_sym
      raise AppConfig::InvalidType unless AppConfig::FORMATS.include?(fmt)
      case fmt
      when :array, :hash
        YAML.load(data)
      when :boolean
        data.eql?('true') ? true : false
      when :integer
        data.to_i
      when :float
        data.to_f
      else
        data
      end
    end
  end
end
