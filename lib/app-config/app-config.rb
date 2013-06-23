require 'active_record'

module AppConfig
  extend AppConfig::Processor

  FORMATS = [:string, :array, :hash, :boolean, :integer, :float].freeze
  FORMATS_MAP = {
    String      => :string,
    Array       => :array,
    Hash        => :hash,
    TrueClass   => :boolean,
    FalseClass  => :boolean,
    Fixnum      => :integer,
    Float       => :float,
  }.freeze
  RESTRICTED_KEYS = [
    'id',
    'to_s',
    'configure',
    'load',
    'flush',
    'reload',
    'keys',
    'empty?',
    'method_missing',
    'exist?',
    'source_model',
    'configuration'
  ].freeze
  
  @@options = {}
  @@records = {}
  
  # Configure app config
  def self.configure(opts={})
    @@options[:model]   = opts[:model]  || Setting
    @@options[:key]     = opts[:key]    || 'keyname'
    @@options[:value]   = opts[:value]  || 'value'
    @@options[:format]  = opts[:format] || 'value_format'
  end
  
  # Returns a configuration options
  def self.configuration
    @@options
  end
  
  # Load and process application settings
  def self.load
    @@records = fetch
  end
  
  # Delete all settings
  def self.flush
    @@records.clear
  end
  
  # Safe method to reload new settings
  def self.reload
    records = fetch rescue nil
    @@records = records || {}
  end
  
  # Manually set (or add) a key
  #def self.set_key(keyname, value, format='string')
    #raise InvalidKeyName, "Invalid key name: #{keyname}" if RESTRICTED_KEYS.include?(keyname)
    #@@records[keyname] = process(value, format)
  #end
  
  # Returns all configuration keys
  def self.keys
    @@records.keys
  end
  
  # Returns true if there are no settings available
  def self.empty?
    @@records.empty?
  end
  
  # Get configuration option
  def self.[](key)
    @@records[key.to_sym]
  end

  def self.[]=(key, value)
    @@records[key.to_sym] = value
  end
  
  # Get configuration option by attribute
  def self.method_missing(method, *args)
    if method[-1].eql?('=')
      @@records[method[0..-2].to_sym] = args.first
    else
      @@records[method.to_sym]
    end
  end
  
  # Returns true if configuration key exists
  def self.exist?(key)
    @@records.key?(key)
  end
  
  # Returns class that defined as source
  def self.source_model
    @@options[:model]
  end

  def self.save
    @@records.each do |key, value|
      format               = format_for_class(value.class)
      source_model.where(keyname: key).first_or_create do |setting| 
        setting.value        = serialize(value, format)
        setting.value_format = format
      end
    end
  end
  
  protected
  
  # Checks the column structure of the source model
  def self.check_structure
    klass = @@options[:model]
    keys = [@@options[:key], @@options[:value], @@options[:format]]
    return (keys - klass.column_names).empty?
  end
  
  # Fetch data from model
  def self.fetch
    raise InvalidSource, 'Model is not defined!'     if @@options[:model].nil?
    raise InvalidSource, 'Model was not found!'      unless @@options[:model].superclass == ActiveRecord::Base
    raise InvalidSource, 'Model fields are invalid!' unless check_structure
    
    records = {}
    
    begin
      source_model.all.each do |setting|
        records[setting.keyname.to_sym] = deserialize(setting.value,
                                            setting.value_format.to_sym) 
      end
      records
    rescue ActiveRecord::StatementInvalid => ex
      raise InvalidSource, ex.message
    end
  end

  private
  def self.format_for_class(klass)
    FORMATS_MAP.each do |key, value|
      return value if key.ancestors.include?(klass)
    end
  end
end
