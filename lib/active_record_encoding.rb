#
# Copyright (c) 2009, Michael H. Buselli
# See LICENSE for details.  All other rights reserved.
#
#######

#
# ActiveRecordEncoding — Module to make ActiveRecord aware of Unicode
# encoding issues.  It should be used only if the underlying database
# and its driver does not or cannot properly handle the encoding of the
# data it returns (usually as "ASCII-8BIT").  Most databases can
# properly encode data, however, so your first assumption should be that
# you do not need this software unless you really know you need it.
#
# ActiveRecordEncoding keeps a variables for each column and table
# where encoding is requested so it knows how the data is encoded in the
# database.  This variable is called its external_encoding.
#
# External encodings must be defined for each column or table where
# a translation is to occur, and this is done in the model definition:
#
#   class User < ActiveRecord::Base
#     external_encoding 'ISO-8859-1', :for => :comment
#     external_encoding 'ISO-8859-1', :for => [:first_name, :last_name]
#   end
#
# Data is converted to UTF-8 when passed to the user.
#
# When data is being saved back to the database, it is assumed that the
# data is in UTF-8, or on Ruby 1.9 if the String's encoding value is
# something other than "ASCII-8BIT" it uses that encoding.
#
module ActiveRecordEncoding
end


# Use Iconv if String objects don't know about #encoding.  This is so
# the library functions on Ruby 1.8.
if not ''.respond_to? :encoding
  require 'iconv'
end


#
# StandardClassMethods defines class methods for inclusion in
# ActiveRecord::Base in order to provide the user interface for
# ActiveRecordEncoding.
#
module ActiveRecordEncoding::StandardClassMethods

  #
  # Set the external_encoding value for this model class.
  #
  #   class User < ActiveRecord::Base
  #     external_encoding 'ISO-8859-1'    # affect all binary columns
  #   end
  #
  # When data is retrieved from the database, it will be assumed it is
  # encoded in the given format.
  #
  # This may also be called with the :for option pointing to one or more
  # specific columns that this call applies to:
  #
  #   class User < ActiveRecord::Base
  #     external_encoding 'ISO-8859-1', :for => :comment
  #     external_encoding 'ISO-8859-1', :for => [:first_name, :last_name]
  #   end
  #
  def external_encoding (new_encoding, options = {})
    extend ActiveRecordEncoding::ExtendedClassMethods
    include ActiveRecordEncoding::IncludedInstanceMethods

    if attr_names = options[:for]
      [*attr_names].each do |attr_name|
        @active_record_encodings[attr_name.to_s][:ext] = new_encoding
      end
    else
      @active_record_external_encoding = new_encoding
    end
  end


  # With the removal of #internal_encoding, the #encoding method is now
  # identical to #external_encoding.
  alias encoding external_encoding

end # ActiveRecordEncoding::StandardClassMethods


#
# ExtendedClassMethods defines class methods for inclusion in
# models sub-classed from ActiveRecord::Base to do the dirty work.  It
# is only included in models that use ActiveRecordEncoding.
#
module ActiveRecordEncoding::ExtendedClassMethods

  def active_record_external_encoding (attr_name = nil) #:nodoc:
    @active_record_encodings[attr_name][:ext] ||
        @active_record_external_encoding
  end


  # Redefine the attribute read method to do the conversion.
  def encoding_aware_define_read_method (symbol, attr_name, column) #:nodoc:
    pre_encoding_aware_define_read_method(symbol, attr_name, column)
    return if active_record_external_encoding(attr_name).nil?
    method_name = "encoding_aware_attr_#{symbol}".to_sym
    old_method_name = "pre_#{method_name}".to_sym
    code = <<-__EOM__
      encoding_aware_attribute_cast!(#{attr_name.inspect}, #{old_method_name})
    __EOM__
    evaluate_attribute_method attr_name, "def #{method_name}; #{code}; end"
    alias_method "pre_#{method_name}".to_sym, symbol
    alias_method symbol, method_name
  end

end # ActiveRecordEncoding::ExtendedClassMethods


#
# IncludedInstanceMethods defines instance methods for inclusion in
# models sub-classed from ActiveRecord::Base to do the dirty work.  It
# is only included in models that use ActiveRecordEncoding.
#
module ActiveRecordEncoding::IncludedInstanceMethods

  def self.included (model_class) #:nodoc:
    return if model_class.instance_variable_get(:@active_record_encodings)

    class << model_class
      alias_method :pre_encoding_aware_define_read_method, :define_read_method
      alias_method :define_read_method, :encoding_aware_define_read_method
    end

    model_class.class_eval do
      @active_record_encodings = Hash.new { |h, k| h[k] = Hash.new }
      alias_method :pre_encoding_aware_read_attribute, :read_attribute
      alias_method :read_attribute, :encoding_aware_read_attribute
      alias_method :pre_encoding_aware_write_attribute, :write_attribute
      alias_method :write_attribute, :encoding_aware_write_attribute
    end
  end

  # Method that casts the Binary data into Unicode, if necessary.  On
  # ":read" operations the value converted from the external encoding to
  # UTF-8 and the operation happens to the value in place.  On ":write"
  # operations the value is cast to 'UTF-8' if no encoding is set, but
  # data is not converted, and the operation happens on a duplicate
  # object.
  def encoding_aware_attribute_cast! (attr_name, value, op = :read) #:nodoc:
    if not value.frozen? and
        not value.instance_variable_get(:@active_record_encoded) \
    then

      if op == :read
        if ext_encoding = self.class.active_record_external_encoding(attr_name)
          if value.respond_to? :encoding
            value.force_encoding(ext_encoding).encode!('UTF-8')
          elsif value.respond_to? :mb_chars
            value.replace Iconv.conv('UTF-8', ext_encoding, value)
          end
        end

      elsif op == :write
        if value.respond_to? :encoding
          (value = value.dup) rescue nil
          value.force_encoding('UTF-8') if value.encoding.name == 'ASCII-8BIT'
        end

      else
        raise "invalid operation"
      end

      value.instance_variable_set(:@active_record_encoded, true)
    end

    value
  end

  # Normal replacement method for read_attribute.
  def pure_encoding_aware_read_attribute (attr_name) #:nodoc:
    value = pre_encoding_aware_read_attribute(attr_name)
    encoding_aware_attribute_cast!(attr_name, value)
  end
  private :pure_encoding_aware_read_attribute


  # Replacement method for read_attribute when Rails is preparing data
  # for write.
  def encoding_aware_read_attribute_for_write (attr_name) #:nodoc:
    value = pure_encoding_aware_read_attribute(attr_name)

    if ext_encoding = self.class.active_record_external_encoding(attr_name)
      if value.respond_to? :encoding
        value = value.encode(ext_encoding).force_encoding('ASCII-8BIT')
      elsif value.respond_to? :mb_chars
        value = Iconv.conv(ext_encoding, 'UTF-8', value)
      end
    end

    value
  end
  private :encoding_aware_read_attribute_for_write


  def encoding_aware_read_attribute (attr_name) #:nodoc:
    # We need to behave differently if called from
    # #attributes_with_quotes because that is how Rails knows what value
    # to write out.  Doing it this way is an unfortunate kludge.
    if caller.grep(/`attributes_with_quotes'$/).empty?
      pure_encoding_aware_read_attribute(attr_name)
    else
      encoding_aware_read_attribute_for_write(attr_name)
    end
  end


  # We need to replace write_attribute so that we can set
  # +@active_record_encoded+ to +true+ on the value being passed in.
  # Otherwise the value is force_encoded according to the rules defined
  # by the user and it results in corrupted data.
  def encoding_aware_write_attribute (attr_name, value) #:nodoc:
    value = encoding_aware_attribute_cast!(attr_name, value, :write)
    pre_encoding_aware_write_attribute(attr_name, value)
  end

end # ActiveRecordEncoding::IncludedInstanceMethods


ActiveRecord::Base.extend ActiveRecordEncoding::StandardClassMethods
