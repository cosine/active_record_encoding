#
# Copyright (c) 2009, Michael H. Buselli
# See LICENSE for details.  All other rights reserved.
#
#######

#
# ActiveRecordEncoding — Module to make ActiveRecord aware of Unicode
# encoding issues on Ruby 1.9.  This software is not supported on Ruby
# 1.8 at all, and never will be.  It should be used only if the
# underlying database does not or cannot properly handle the encoding of
# data that is returned as "ASCII-8BIT" encoded data.  Most databases
# can properly encode data, so your first assumption should be that you
# do not need this software unless you really know you need it.
#
# ActiveRecordEncoding keeps two variables on the default encoding to
# use when accessing the database.
#
#   ActiveRecordEncoding.external_encoding = 'ISO-8859-1'
#   ActiveRecordEncoding.internal_encoding = 'UTF-8'
#
# Deprecation Notice:  ActiveRecordEncoding.external_encoding will be
# discontinued in favor of explicitly setting encodings for particular
# tables and columns in a future version.
#
# If the external_encoding is not explicitly set then no conversions
# will be done.  The internal_encoding value defaults to
# Encoding.default_internal if not explicitly set.
#
# The internal_encoding value is the encoding of the Strings that are
# returned by ActiveRecord from String-based columns.  The
# external_encoding value tells ActiveRecord how the database is
# actually encoding the data that is being returned as "ASCII-8BIT".
# A conversion is done if necessary.
#
# When data is being saved back to the database, the internal_encoding
# value is ignored and the encoding of the input is used to determine
# how to encode the data in the external_encoding.
#
# Encodings may also be defined on a table-by-table basis or
# a column-by-column basis in the model definition.
#
module ActiveRecordEncoding

  class << self
    attr_accessor :external_encoding, :internal_encoding
  end

  #
  # Set both ActiveRecordEncoding.external_encoding and
  # ActiveRecordEncoding.internal_encoding in a single method.
  #
  #   ActiveRecordEncoding.encoding = 'UTF-8'
  #
  def encoding= (new_encoding)
    @internal_encoding = @external_encoding = new_encoding
  end
  module_function :encoding=
end



module ActiveRecordEncoding::ActiveRecordExtensionClassMethods

  def active_record_encodings
    @active_record_encodings ||= Hash.new { |h, k| h[k] = Hash.new }
  end

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
    if attr_names = options[:for]
      [*attr_names].each do |attr_name|
        active_record_encodings[attr_name.to_s][:ext] = new_encoding
      end
    else
      @active_record_external_encoding = new_encoding
    end
  end

  #
  # Set the internal_encoding value for this model class.
  #
  #   class User < ActiveRecord::Base
  #     internal_encoding 'UTF-8'   # affect all binary columns
  #   end
  #
  # When String objects are returned to the user as a result of an
  # ActiveRecord database lookup, they will be in the given format.
  #
  # This may also be called with the :for option pointing to one or more
  # specific columns that this call applies to:
  #
  #   class User < ActiveRecord::Base
  #     internal_encoding 'ISO-8859-1', :for => :comment
  #     internal_encoding 'ISO-8859-1', :for => [:first_name, :last_name]
  #   end
  #
  def internal_encoding (new_encoding, options = {})
    if attr_names = options[:for]
      [*attr_names].each do |attr_name|
        active_record_encodings[attr_name.to_s][:int] = new_encoding
      end
    else
      @active_record_internal_encoding = new_encoding
    end
  end

  #
  # Set both the external_encoding and the internal_encoding values for
  # this model class.
  #
  #   class User < ActiveRecord::Base
  #     encoding 'UTF-8'    # affect all binary columns
  #   end
  #
  # When data is retrived from the database, it will be assumed it is
  # encoded in the given format and returned in the same format.
  #
  # This may also be called with the :for option pointing to one or more
  # specific columns that this call applies to:
  #
  #   class User < ActiveRecord::Base
  #     encoding 'ISO-8859-1', :for => :comment
  #     encoding 'ISO-8859-1', :for => [:first_name, :last_name]
  #   end
  #
  def encoding (new_encoding, options = {})
    if attr_names = options[:for]
      [*attr_names].each do |attr_name|
        active_record_encodings[attr_name.to_s] =
            { :ext => new_encoding, :int => new_encoding }
      end
    else
      @active_record_external_encoding = new_encoding
      @active_record_internal_encoding = new_encoding
    end
  end

  def active_record_external_encoding (attr_name = nil) #:nodoc:
    active_record_encodings[attr_name][:ext] ||
        @active_record_external_encoding ||
        ActiveRecordEncoding.external_encoding
  end

  def active_record_internal_encoding (attr_name = nil) #:nodoc:
    active_record_encodings[attr_name][:int] ||
        @active_record_internal_encoding ||
        ActiveRecordEncoding.internal_encoding ||
        Encoding.default_internal ||
        Encoding.default_external ||
        'UTF-8'
  end


  # Redefine the attribute read method to do the conversion.
  def encoding_aware_define_read_method (symbol, attr_name, column) #:nodoc:
    pre_encoding_aware_define_read_method(symbol, attr_name, column)
    method_name = "encoding_aware_attr_#{symbol}".to_sym
    old_method_name = "pre_#{method_name}".to_sym
    code = <<-__EOM__
      encoding_aware_attribute_cast!(#{attr_name.inspect}, #{old_method_name})
    __EOM__
    evaluate_attribute_method attr_name, "def #{method_name}; #{code}; end"
    alias_method "pre_#{method_name}".to_sym, symbol
    alias_method symbol, method_name
  end
end


class ActiveRecord::Base #:nodoc:
  extend ActiveRecordEncoding::ActiveRecordExtensionClassMethods

  class << self
    alias_method :pre_encoding_aware_define_read_method, :define_read_method
    alias_method :define_read_method, :encoding_aware_define_read_method
  end

  # Method that casts the Binary data into Unicode, if necessary.
  def encoding_aware_attribute_cast! (attr_name, value) #:nodoc:
    if value.respond_to? :encoding and
        value.encoding.to_s.eql?('ASCII-8BIT') and
        ext_encoding = self.class.active_record_external_encoding(attr_name) \
    then
      int_encoding = self.class.active_record_internal_encoding(attr_name)
      value.force_encoding(ext_encoding).encode!(int_encoding)
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

    if value.respond_to? :encoding and
          ext_encoding = self.class.active_record_external_encoding(attr_name)
      value = value.encode(ext_encoding).force_encoding('ASCII-8BIT')
    end

    value
  end
  private :encoding_aware_read_attribute_for_write


  def encoding_aware_read_attribute (attr_name) #:nodoc:
    # We need to behave differently if called from
    # #attributes_with_quotes because that is how Rails knows what value
    # to write out.  Doing it this way is an unfortunate kludge.
    rc = if caller.grep(/`attributes_with_quotes'$/).empty?
      pure_encoding_aware_read_attribute(attr_name)
    else
      encoding_aware_read_attribute_for_write(attr_name)
    end
  end

  alias_method :pre_encoding_aware_read_attribute, :read_attribute
  alias_method :read_attribute, :encoding_aware_read_attribute
end
