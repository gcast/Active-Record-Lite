require_relative 'db_connection'
require_relative '01_mass_object'
require 'active_support/inflector'

class MassObject

  def self.parse_all(results)
    results.map { |result| self.new(result) }
  end
  
end

class SQLObject < MassObject

  def self.columns  
    columns = DBConnection.execute2("SELECT * FROM #{table_name}")[0]

    columns.each do |col|
      define_method(col) { attributes[col] }
      define_method("#{col}=") { |val| attributes[col] = val }
    end
    columns.map(&:to_sym)
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    if @table_name.nil?
      @table_name = "#{self}".underscore.pluralize
    else
      @table_name
    end
  end

  def self.all
    results = DBConnection.execute(<<-SQL)
      SELECT
    #{ table_name }.*
      FROM
    #{ table_name }
    SQL

    parse_all(results)
  end

  def self.find(id)
    result = DBConnection.execute(<<-SQL, id)
      SELECT
    #{ table_name }.*
      FROM
    #{ table_name }
      WHERE
      id = ?
    SQL

    self.new(result[0])
  end

  def name
    attributes[name]
  end

  def attributes
    @attributes = @attributes.nil? ? {} : @attributes
  end

  def insert
    col_names = attributes.keys.join(', ')
    qmarks = (["?"] * attribute_values.count).join(', ')

    DBConnection.execute(<<-SQL, *attribute_values)
      INSERT INTO
        #{ self.class.table_name } (#{col_names})
      VALUES 
        (#{qmarks})
    SQL

    self.id = DBConnection.last_insert_row_id
  end

  def initialize(params = {}) #hash
    params.each do |key, value|
      key_sym = key.to_sym
      if self.class.columns.include?(key_sym)
        self.send("#{key_sym}=", value)
      else
        raise "unknown attribute '#{key_sym}'"
      end
    end
  end

  def save
    self.id.nil? ? self.insert : self.update
  end

  def update
    set_line = attributes.keys.map {|key| "#{key} = ?"}.join(', ')

    DBConnection.execute(<<-SQL, *attribute_values, self.id)
      UPDATE
        #{self.class.table_name}
      SET 
        #{set_line}
      WHERE
        id = ?
    SQL
  end

  def attribute_values
    attributes.values
  end
end
