# An BasePresenter for a JSON Schema fragment. Like most JSON
# schema things, has a tendency to recurse.
class Lurker::SchemaPresenter < Lurker::BasePresenter
  attr_reader :schema

  FORMATTED_KEYS = %w(
    description
    type
    required
    example
    deprecated
    default
    format
    enum
    items
    properties
    $ref
  )

  def initialize(schema, options)
    options[:nested] ||= 0
    super(options)
    @schema = schema
  end

  def request?
    options[:request]
  end

  def nested?
    options[:nested] > 0
  end

  def to_html(parent_key=nil)
    html = StringIO.new

    html << '<span class="deprecated">Deprecated</span>' if deprecated?

    html << '<div class="schema">'
    html << @schema["description"]

    html << '<ul>'
    begin
      html << '<li>Required: %s</li>' % required?(parent_key) if nested?
      html << '<li>Type: %s</li>' % type if type
      html << '<li>Format: %s</li>' % format if format
      html << '<li>Example: %s</li>' % example.to_html if example
      html << enum_html

      (@schema.keys - FORMATTED_KEYS).each do |key|
        html << '<li>%s: %s</li>' % [ key, @schema[key] ]
      end

      html << items_html
      html << properties_html
    end


    html << '</ul>'
    html << '</div>'

    html.string
  end

  def type
    t = @schema["type"]
    if t.kind_of? Array
      types = t.map do |type|
        if type.kind_of? Hash
          '<li>%s</li>' % self.class.new(type, options.merge(parent: self)).to_html
        else
          '<li>%s</li>' % type
        end
      end.join('')

      '<ul>%s</ul>' % types
    elsif t != "object"
      t
    end
  end

  def format
    @schema["format"]
  end

  def example
    return unless @schema.key?("example")

    Lurker::JsonPresenter.new(@schema["example"])
  end

  def deprecated?
    @schema["deprecated"]
  end

  def required?(parent_key=nil)
    ((options[:parent].schema['required'] || []).include?(parent_key)) ? "yes" : "no"
  end

  def enum_html
    enum = @schema["enum"]
    return unless enum

    list = enum.map do |e|
      '<tt>%s</tt>' % e
    end.join(", ")

    html = StringIO.new
    html << '<li>Enum: '
    html << list
    html << '</li>'
    html.string
  end

  def items_html
    return unless items = @schema["items"]

    html = ""
    html << '<li>Items'

    sub_options = options.merge(:nested => options[:nested] + 1, :parent => self)

    if items.kind_of? Array
      item.compact.each do |item|
        html << self.class.new(item, sub_options).to_html
      end
    else
      html << self.class.new(items, sub_options).to_html
    end

    html << '</li>'
    html
  end

  def properties_html
    properties = if (props = @schema["properties"]).present?
      props
    elsif (ref_path = @schema["$ref"]).present?
      ref = Lurker::RefObject.new(ref_path, options[:root_path])
      options[:root_path] = options[:root_path].merge(ref_path.sub(/#[^#]*?$/, ''))
      ref.schema["properties"]
    else
      nil
    end

    return unless properties

    html = ""

    properties.each do |key, property|
      next if property.nil?
      html << '<li>'
      html << tag_with_anchor(
        'span',
        '<tt>%s</tt>' % key,
        schema_slug(key, property)
      )
      html << self.class.new(property, options.merge(:nested => options[:nested] + 1, :parent => self)).to_html(key)
      html << '</li>'
    end

    html
  end

  def schema_slug(key, property)
    "#{key}-#{options[:nested]}-#{property.hash}"
  end
end
